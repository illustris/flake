#include "bspLayout.hpp"
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/debug/log/Logger.hpp>
#include <format>

void CBSPAlgorithm::applyTreeGeometry(SBSPNode* node) {
	if (!node)
		return;

	if (node->isLeaf) {
		if (node->target)
			node->target->setPositionGlobal(node->box);
	} else {
		applyTreeGeometry(node->left.get());
		applyTreeGeometry(node->right.get());
	}
}

SBSPNode* CBSPAlgorithm::getNodeFromTarget(SP<Layout::ITarget> target, SBSPNode* root) {
	if (!root)
		return nullptr;

	if (root->isLeaf)
		return root->target == target ? root : nullptr;

	auto leftResult = getNodeFromTarget(target, root->left.get());
	if (leftResult)
		return leftResult;

	return getNodeFromTarget(target, root->right.get());
}

SBSPNode* CBSPAlgorithm::getParentNode(SBSPNode* child, SBSPNode* root) {
	if (!root || root->isLeaf)
		return nullptr;

	if (root->left.get() == child || root->right.get() == child)
		return root;

	auto leftResult = getParentNode(child, root->left.get());
	if (leftResult)
		return leftResult;

	return getParentNode(child, root->right.get());
}

SBSPNode* CBSPAlgorithm::findLargestLeafNode(SBSPNode* node) {
	if (!node || node->isLeaf)
		return node;

	auto leftLargest = findLargestLeafNode(node->left.get());
	auto rightLargest = findLargestLeafNode(node->right.get());

	if (!leftLargest) return rightLargest;
	if (!rightLargest) return leftLargest;

	float leftSize = leftLargest->box.w * leftLargest->box.h;
	float rightSize = rightLargest->box.w * rightLargest->box.h;

	Log::logger->log(Log::INFO, "[BSP] findLargest: left box({},{} {}x{}) area={}, right box({},{} {}x{}) area={}, picking {}",
		leftLargest->box.x, leftLargest->box.y, leftLargest->box.w, leftLargest->box.h, leftSize,
		rightLargest->box.x, rightLargest->box.y, rightLargest->box.w, rightLargest->box.h, rightSize,
		leftSize > rightSize ? "left" : "right");

	return leftSize > rightSize ? leftLargest : rightLargest;
}

void CBSPAlgorithm::splitNode(SBSPNode* node, SP<Layout::ITarget> newTarget) {
	if (!node || !node->isLeaf)
		return;

	bool splitHorizontally = node->box.w < node->box.h;
	node->splitDir = splitHorizontally ? SplitDirection::HORIZONTAL : SplitDirection::VERTICAL;
	node->isLeaf = false;

	node->left = std::make_unique<SBSPNode>(node->target);
	node->right = std::make_unique<SBSPNode>(newTarget);

	if (splitHorizontally) {
		node->left->box = CBox(node->box.pos(), {node->box.w, node->box.h * node->splitRatio});
		node->right->box = CBox({node->box.x, node->box.y + node->box.h * node->splitRatio},
							{node->box.w, node->box.h * (1.0f - node->splitRatio)});
	} else {
		node->left->box = CBox(node->box.pos(), {node->box.w * node->splitRatio, node->box.h});
		node->right->box = CBox({node->box.x + node->box.w * node->splitRatio, node->box.y},
							{node->box.w * (1.0f - node->splitRatio), node->box.h});
	}

	node->target = nullptr;
}

void CBSPAlgorithm::recalculateTreeBoxes(SBSPNode* node) {
	if (!node || node->isLeaf)
		return;

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

	recalculateTreeBoxes(node->left.get());
	recalculateTreeBoxes(node->right.get());
}

SBSPNode* CBSPAlgorithm::removeTargetFromTree(SBSPNode* node, SP<Layout::ITarget> target, bool& found) {
	if (!node)
		return nullptr;

	if (node->isLeaf) {
		if (node->target == target) {
			found = true;
			return nullptr;
		}
		return node;
	}

	auto newLeft = removeTargetFromTree(node->left.get(), target, found);
	if (!found) {
		auto newRight = removeTargetFromTree(node->right.get(), target, found);
		if (!found)
			return node;

		// Target was in right child, promote left
		if (!newRight && node->left) {
			auto leftChild = std::move(node->left);
			node->isLeaf = leftChild->isLeaf;
			node->target = leftChild->target;
			node->splitDir = leftChild->splitDir;
			node->splitRatio = leftChild->splitRatio;
			node->left = std::move(leftChild->left);
			node->right = std::move(leftChild->right);
		}
	} else {
		// Target was in left child, promote right
		if (!newLeft && node->right) {
			auto rightChild = std::move(node->right);
			node->isLeaf = rightChild->isLeaf;
			node->target = rightChild->target;
			node->splitDir = rightChild->splitDir;
			node->splitRatio = rightChild->splitRatio;
			node->left = std::move(rightChild->left);
			node->right = std::move(rightChild->right);
		}
	}

	return node;
}

void CBSPAlgorithm::collectLeaves(SBSPNode* node, std::vector<SBSPNode*>& leaves) {
	if (!node)
		return;

	if (node->isLeaf) {
		leaves.push_back(node);
		return;
	}

	collectLeaves(node->left.get(), leaves);
	collectLeaves(node->right.get(), leaves);
}

SBSPNode* CBSPAlgorithm::findAdjacentLeaf(SBSPNode* targetNode, Math::eDirection dir, SBSPNode* root) {
	if (!targetNode || !root)
		return nullptr;

	// Collect all leaves and find by geometric adjacency
	std::vector<SBSPNode*> leaves;
	collectLeaves(root, leaves);

	auto& box = targetNode->box;
	float cx = box.x + box.w / 2.0f;
	float cy = box.y + box.h / 2.0f;

	SBSPNode* best = nullptr;
	float bestDist = std::numeric_limits<float>::max();

	for (auto* leaf : leaves) {
		if (leaf == targetNode)
			continue;

		auto& lb = leaf->box;
		float lcx = lb.x + lb.w / 2.0f;
		float lcy = lb.y + lb.h / 2.0f;

		bool valid = false;
		switch (dir) {
			case Math::eDirection::DIRECTION_LEFT:  valid = lcx < cx; break;
			case Math::eDirection::DIRECTION_RIGHT: valid = lcx > cx; break;
			case Math::eDirection::DIRECTION_UP:    valid = lcy < cy; break;
			case Math::eDirection::DIRECTION_DOWN:  valid = lcy > cy; break;
			default: break;
		}

		if (!valid)
			continue;

		float dist = (lcx - cx) * (lcx - cx) + (lcy - cy) * (lcy - cy);
		if (dist < bestDist) {
			bestDist = dist;
			best = leaf;
		}
	}

	return best;
}

// --- IModeAlgorithm implementation ---

void CBSPAlgorithm::newTarget(SP<Layout::ITarget> target) {
	if (!m_parent.lock())
		return;

	CBox workArea = m_parent.lock()->space()->workArea();

	if (!m_root) {
		Log::logger->log(Log::INFO, "[BSP] newTarget: first window, workArea=({},{} {}x{})", workArea.x, workArea.y, workArea.w, workArea.h);
		m_root = std::make_unique<SBSPNode>(target);
		m_root->box = workArea;
		target->setPositionGlobal(workArea);
	} else {
		SBSPNode* largestNode = findLargestLeafNode(m_root.get());
		if (largestNode) {
			Log::logger->log(Log::INFO, "[BSP] newTarget: splitting largest at ({},{} {}x{}), area={}",
				largestNode->box.x, largestNode->box.y, largestNode->box.w, largestNode->box.h,
				largestNode->box.w * largestNode->box.h);
			splitNode(largestNode, target);
			applyTreeGeometry(m_root.get());
		}
	}
}

void CBSPAlgorithm::movedTarget(SP<Layout::ITarget> target, std::optional<Vector2D> focalPoint) {
	// Treat same as newTarget
	newTarget(target);
}

void CBSPAlgorithm::removeTarget(SP<Layout::ITarget> target) {
	if (!m_root)
		return;

	bool found = false;
	auto newRoot = removeTargetFromTree(m_root.get(), target, found);

	if (!newRoot) {
		m_root.reset();
	} else if (found) {
		recalculateTreeBoxes(m_root.get());
		applyTreeGeometry(m_root.get());
	}
}

void CBSPAlgorithm::resizeTarget(const Vector2D& delta, SP<Layout::ITarget> target, Layout::eRectCorner corner) {
	if (!m_root || !target)
		return;

	auto* node = getNodeFromTarget(target, m_root.get());
	if (!node)
		return;

	auto* parent = getParentNode(node, m_root.get());
	if (!parent)
		return;

	// Adjust split ratio based on delta
	if (parent->splitDir == SplitDirection::HORIZONTAL) {
		float adjustment = delta.y / parent->box.h;
		if (parent->left.get() == node)
			parent->splitRatio += adjustment;
		else
			parent->splitRatio -= adjustment;
	} else {
		float adjustment = delta.x / parent->box.w;
		if (parent->left.get() == node)
			parent->splitRatio += adjustment;
		else
			parent->splitRatio -= adjustment;
	}

	parent->splitRatio = std::clamp(parent->splitRatio, 0.1f, 0.9f);

	recalculateTreeBoxes(m_root.get());
	applyTreeGeometry(m_root.get());
}

void CBSPAlgorithm::recalculate() {
	if (!m_root || !m_parent.lock())
		return;

	m_root->box = m_parent.lock()->space()->workArea();
	recalculateTreeBoxes(m_root.get());
	applyTreeGeometry(m_root.get());
}

void CBSPAlgorithm::swapTargets(SP<Layout::ITarget> a, SP<Layout::ITarget> b) {
	if (!m_root)
		return;

	auto* nodeA = getNodeFromTarget(a, m_root.get());
	auto* nodeB = getNodeFromTarget(b, m_root.get());

	if (!nodeA || !nodeB)
		return;

	std::swap(nodeA->target, nodeB->target);
	applyTreeGeometry(m_root.get());
}

void CBSPAlgorithm::moveTargetInDirection(SP<Layout::ITarget> t, Math::eDirection dir, bool silent) {
	if (!m_root || !t)
		return;

	auto* node = getNodeFromTarget(t, m_root.get());
	if (!node)
		return;

	auto* adjacent = findAdjacentLeaf(node, dir, m_root.get());
	if (!adjacent)
		return;

	std::swap(node->target, adjacent->target);
	applyTreeGeometry(m_root.get());
}

SP<Layout::ITarget> CBSPAlgorithm::getNextCandidate(SP<Layout::ITarget> old) {
	if (!m_root)
		return nullptr;

	std::vector<SBSPNode*> leaves;
	collectLeaves(m_root.get(), leaves);

	if (leaves.empty())
		return nullptr;

	if (!old)
		return leaves.front()->target;

	// Find current and return the next one
	for (size_t i = 0; i < leaves.size(); i++) {
		if (leaves[i]->target == old) {
			size_t next = (i + 1) % leaves.size();
			return leaves[next]->target;
		}
	}

	return leaves.front()->target;
}

std::expected<void, std::string> CBSPAlgorithm::layoutMsg(const std::string_view& sv) {
	// Can implement custom commands (e.g., "rotate", "balance") here
	return std::unexpected("unknown command");
}

std::optional<Vector2D> CBSPAlgorithm::predictSizeForNewTarget() {
	return Vector2D{600, 400};
}
