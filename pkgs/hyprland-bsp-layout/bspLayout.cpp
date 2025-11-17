#include "bspLayout.hpp"
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/Window.hpp>
#include <hyprland/src/config/ConfigManager.hpp>

CBSPLayout::~CBSPLayout() {}

void CBSPLayout::onEnable() {
	for (auto& w : g_pCompositor->m_windows) {
		if (w->isHidden() || !w->m_isMapped || w->m_fadingOut || w->m_isFloating)
			continue;

		onWindowCreatedTiling(w, DIRECTION_DEFAULT);
	}
}

void CBSPLayout::onDisable() {
	m_mWorkspaceRoots.clear();
}

CBox CBSPLayout::getWorkspaceBox(PHLWORKSPACE workspace) {
	if (!workspace || !workspace->m_monitor)
		return CBox();

	auto monitor = workspace->m_monitor;
	return CBox(monitor->m_position, monitor->m_size);
}

void CBSPLayout::applyNodeGeometry(PHLWINDOW window, const CBox& box) {
	if (!window || !window->m_isMapped)
		return;

	window->unsetWindowData(PRIORITY_LAYOUT);

	CBox nodeBox = box;
	nodeBox.round();

	window->m_size = nodeBox.size();
	window->m_position = nodeBox.pos();

	auto reserved = window->getFullWindowReservedArea();

	*window->m_realPosition = window->m_position + reserved.topLeft;
	*window->m_realSize = window->m_size - (reserved.topLeft + reserved.bottomRight);

	window->updateWindowDecos();
	window->sendWindowSize(true);
}

void CBSPLayout::applyTreeGeometry(SBSPNode* node) {
	if (!node)
		return;

	if (node->isLeaf) {
		if (node->window)
			applyNodeGeometry(node->window, node->box);
	} else {
		if (node->left)
			applyTreeGeometry(node->left.get());
		if (node->right)
			applyTreeGeometry(node->right.get());
	}
}

SBSPNode* CBSPLayout::getNodeFromWindow(PHLWINDOW pWindow, SBSPNode* root) {
	if (!root)
		return nullptr;

	if (root->isLeaf) {
		return root->window == pWindow ? root : nullptr;
	}

	auto leftResult = getNodeFromWindow(pWindow, root->left.get());
	if (leftResult)
		return leftResult;

	return getNodeFromWindow(pWindow, root->right.get());
}

SBSPNode* CBSPLayout::findLargestLeafNode(SBSPNode* node) {
	if (!node || node->isLeaf)
		return node;

	// Recursively find largest leaf
	auto leftLargest = findLargestLeafNode(node->left.get());
	auto rightLargest = findLargestLeafNode(node->right.get());

	if (!leftLargest) return rightLargest;
	if (!rightLargest) return leftLargest;

	// Compare sizes
	float leftSize = leftLargest->box.w * leftLargest->box.h;
	float rightSize = rightLargest->box.w * rightLargest->box.h;

	return leftSize > rightSize ? leftLargest : rightLargest;
}

void CBSPLayout::splitNode(SBSPNode* node, PHLWINDOW newWindow) {
	if (!node || !node->isLeaf)
		return;

	// Determine split direction based on longest side
	bool splitHorizontally = node->box.w < node->box.h;
	node->splitDir = splitHorizontally ? SplitDirection::HORIZONTAL : SplitDirection::VERTICAL;
	node->isLeaf = false;

	// Create two leaf nodes
	node->left = std::make_unique<SBSPNode>(node->window);
	node->right = std::make_unique<SBSPNode>(newWindow);

	// Distribute space
	if (splitHorizontally) {
		node->left->box = CBox(node->box.pos(), {node->box.w, node->box.h * node->splitRatio});
		node->right->box = CBox({node->box.x, node->box.y + node->box.h * node->splitRatio},
							{node->box.w, node->box.h * (1.0f - node->splitRatio)});
	} else {
		node->left->box = CBox(node->box.pos(), {node->box.w * node->splitRatio, node->box.h});
		node->right->box = CBox({node->box.x + node->box.w * node->splitRatio, node->box.y},
							{node->box.w * (1.0f - node->splitRatio), node->box.h});
	}

	node->window = nullptr; // Parent node no longer holds window
}

void CBSPLayout::recalculateTreeBoxes(SBSPNode* node) {
	if (!node || node->isLeaf)
		return;

	// Recalculate child boxes based on current node's box and split
	if (node->splitDir == SplitDirection::HORIZONTAL) {
		if (node->left) {
			node->left->box = CBox(node->box.pos(),
				{node->box.w, node->box.h * node->splitRatio});
		}
		if (node->right) {
			node->right->box = CBox({node->box.x, node->box.y + node->box.h * node->splitRatio},
				{node->box.w, node->box.h * (1.0f - node->splitRatio)});
		}
	} else {
		if (node->left) {
			node->left->box = CBox(node->box.pos(),
				{node->box.w * node->splitRatio, node->box.h});
		}
		if (node->right) {
			node->right->box = CBox({node->box.x + node->box.w * node->splitRatio, node->box.y},
				{node->box.w * (1.0f - node->splitRatio), node->box.h});
		}
	}

	// Recursively recalculate children
	recalculateTreeBoxes(node->left.get());
	recalculateTreeBoxes(node->right.get());
}

SBSPNode* CBSPLayout::removeWindowFromTree(SBSPNode* node, PHLWINDOW window, bool& found) {
	if (!node)
		return nullptr;

	if (node->isLeaf) {
		if (node->window == window) {
			found = true;
			return nullptr; // Remove this leaf
		}
		return node;
	}

	// Recursively search in children
	auto newLeft = removeWindowFromTree(node->left.get(), window, found);
	if (!found) {
		auto newRight = removeWindowFromTree(node->right.get(), window, found);
		if (!found)
			return node; // Window not found in this subtree

		// Window was in right child
		if (!newRight) {
			// Right child was removed, promote left child
			// Move ownership from left child before destroying it
			if (node->left) {
				auto leftChild = std::move(node->left);
				node->isLeaf = leftChild->isLeaf;
				node->window = leftChild->window;
				node->splitDir = leftChild->splitDir;
				node->splitRatio = leftChild->splitRatio;
				node->left = std::move(leftChild->left);
				node->right = std::move(leftChild->right);
			}
			return node;
		}
	} else {
		// Window was in left child
		if (!newLeft) {
			// Left child was removed, promote right child
			// Move ownership from right child before destroying it
			if (node->right) {
				auto rightChild = std::move(node->right);
				node->isLeaf = rightChild->isLeaf;
				node->window = rightChild->window;
				node->splitDir = rightChild->splitDir;
				node->splitRatio = rightChild->splitRatio;
				node->left = std::move(rightChild->left);
				node->right = std::move(rightChild->right);
			}
			return node;
		}
	}

	return node;
}

void CBSPLayout::onWindowCreatedTiling(PHLWINDOW pWindow, eDirection direction) {
	if (pWindow->m_isFloating)
		return;

	auto workspace = pWindow->m_workspace;
	if (!workspace)
		return;

	CBox workspaceBox = getWorkspaceBox(workspace);

	// Check if this workspace has a tree
	auto it = m_mWorkspaceRoots.find(workspace);

	if (it == m_mWorkspaceRoots.end()) {
		// First window on workspace
		auto newRoot = std::make_unique<SBSPNode>(pWindow);
		newRoot->box = workspaceBox;
		m_mWorkspaceRoots[workspace] = std::move(newRoot);
		applyNodeGeometry(pWindow, workspaceBox);
	} else {
		// Find largest window and split it
		SBSPNode* largestNode = findLargestLeafNode(it->second.get());

		if (largestNode) {
			splitNode(largestNode, pWindow);
			applyTreeGeometry(it->second.get());
		}
	}
}

bool CBSPLayout::isWindowTiled(PHLWINDOW pWindow) {
	auto workspace = pWindow->m_workspace;
	if (!workspace)
		return false;

	auto it = m_mWorkspaceRoots.find(workspace);
	if (it == m_mWorkspaceRoots.end())
		return false;

	return getNodeFromWindow(pWindow, it->second.get()) != nullptr;
}

void CBSPLayout::onWindowRemovedTiling(PHLWINDOW pWindow) {
	auto workspace = pWindow->m_workspace;
	if (!workspace)
		return;

	auto it = m_mWorkspaceRoots.find(workspace);
	if (it == m_mWorkspaceRoots.end())
		return;

	bool found = false;
	auto newRoot = removeWindowFromTree(it->second.get(), pWindow, found);

	if (!newRoot) {
		// Tree is empty, remove it
		m_mWorkspaceRoots.erase(it);
	} else if (found) {
		// Recalculate all box geometries in the tree
		recalculateTreeBoxes(it->second.get());
		// Apply the updated geometry to all windows
		applyTreeGeometry(it->second.get());
	}
}

void CBSPLayout::recalculateMonitor(const MONITORID& monid) {
	const auto PMONITOR = g_pCompositor->getMonitorFromID(monid);
	if (!PMONITOR)
		return;

	// Recalculate all workspaces on this monitor
	for (auto& [workspace, root] : m_mWorkspaceRoots) {
		if (!workspace || workspace->m_monitor != PMONITOR)
			continue;

		// Update root box
		root->box = getWorkspaceBox(workspace);

		// Recalculate all boxes in the tree
		recalculateTreeBoxes(root.get());

		// Apply the updated geometry
		applyTreeGeometry(root.get());
	}
}

void CBSPLayout::recalculateWindow(PHLWINDOW pWindow) {
	auto workspace = pWindow->m_workspace;
	if (!workspace)
		return;

	auto it = m_mWorkspaceRoots.find(workspace);
	if (it == m_mWorkspaceRoots.end())
		return;

	// Update root box and recalculate tree
	it->second->box = getWorkspaceBox(workspace);
	recalculateTreeBoxes(it->second.get());
	applyTreeGeometry(it->second.get());
}

void CBSPLayout::resizeActiveWindow(const Vector2D& delta, eRectCorner corner, PHLWINDOW pWindow) {
	if (!pWindow)
		pWindow = g_pCompositor->m_lastWindow.lock();

	if (!pWindow)
		return;

	// For now, just recalculate
	// A full implementation would adjust split ratios
	recalculateWindow(pWindow);
}

void CBSPLayout::fullscreenRequestForWindow(PHLWINDOW pWindow, const eFullscreenMode CURRENT_EFFECTIVE_MODE, const eFullscreenMode EFFECTIVE_MODE) {
	// Hyprland handles fullscreen internally, we just need to restore layout after
	if (EFFECTIVE_MODE == FSMODE_NONE)
		recalculateWindow(pWindow);
}

std::any CBSPLayout::layoutMessage(SLayoutMessageHeader header, std::string message) {
	// Can implement custom commands here (e.g., "rotate", "balance")
	return std::any();
}

SWindowRenderLayoutHints CBSPLayout::requestRenderHints(PHLWINDOW pWindow) {
	return SWindowRenderLayoutHints();
}

void CBSPLayout::switchWindows(PHLWINDOW pWindow, PHLWINDOW pWindow2) {
	auto workspace = pWindow->m_workspace;
	if (!workspace)
		return;

	auto it = m_mWorkspaceRoots.find(workspace);
	if (it == m_mWorkspaceRoots.end())
		return;

	auto node1 = getNodeFromWindow(pWindow, it->second.get());
	auto node2 = getNodeFromWindow(pWindow2, it->second.get());

	if (!node1 || !node2)
		return;

	std::swap(node1->window, node2->window);
	applyTreeGeometry(it->second.get());
}

void CBSPLayout::moveWindowTo(PHLWINDOW pWindow, const std::string& direction, bool silent) {
	// Simplified: not implemented
	// Would need to swap with window in specified direction
}

void CBSPLayout::alterSplitRatio(PHLWINDOW pWindow, float delta, bool exact) {
	// Would adjust the split ratio of parent node
	recalculateWindow(pWindow);
}

std::string CBSPLayout::getLayoutName() {
	return "bsp";
}

void CBSPLayout::replaceWindowDataWith(PHLWINDOW from, PHLWINDOW to) {
	auto workspace = from->m_workspace;
	if (!workspace)
		return;

	auto it = m_mWorkspaceRoots.find(workspace);
	if (it == m_mWorkspaceRoots.end())
		return;

	auto node = getNodeFromWindow(from, it->second.get());
	if (node)
		node->window = to;
}

Vector2D CBSPLayout::predictSizeForNewWindowTiled() {
	// Return a reasonable default
	return {600, 400};
}
