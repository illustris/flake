#pragma once

#include <hyprland/src/layout/IHyprLayout.hpp>
#include <map>
#include <memory>

enum class SplitDirection {
	HORIZONTAL,
	VERTICAL
};

struct SBSPNode {
	bool isLeaf = true;
	PHLWINDOW window = nullptr;

	// For non-leaf nodes
	SplitDirection splitDir;
	std::unique_ptr<SBSPNode> left;
	std::unique_ptr<SBSPNode> right;
	float splitRatio = 0.5f;

	// Geometry
	CBox box;

	SBSPNode() = default;
	SBSPNode(PHLWINDOW w) : window(w) {}
};

class CBSPLayout : public IHyprLayout {
public:
	virtual ~CBSPLayout();

	// Required virtual methods from IHyprLayout
	virtual void onEnable() override;
	virtual void onDisable() override;
	virtual void onWindowCreatedTiling(PHLWINDOW, eDirection direction) override;
	virtual bool isWindowTiled(PHLWINDOW) override;
	virtual void onWindowRemovedTiling(PHLWINDOW) override;
	virtual void recalculateMonitor(const MONITORID&) override;
	virtual void recalculateWindow(PHLWINDOW) override;
	virtual void resizeActiveWindow(const Vector2D&, eRectCorner corner, PHLWINDOW) override;
	virtual void fullscreenRequestForWindow(PHLWINDOW, const eFullscreenMode, const eFullscreenMode) override;
	virtual std::any layoutMessage(SLayoutMessageHeader, std::string) override;
	virtual SWindowRenderLayoutHints requestRenderHints(PHLWINDOW) override;
	virtual void switchWindows(PHLWINDOW, PHLWINDOW) override;
	virtual void moveWindowTo(PHLWINDOW, const std::string& direction, bool silent) override;
	virtual void alterSplitRatio(PHLWINDOW, float delta, bool exact) override;
	virtual std::string getLayoutName() override;
	virtual void replaceWindowDataWith(PHLWINDOW from, PHLWINDOW to) override;
	virtual Vector2D predictSizeForNewWindowTiled() override;

private:
	// Map of workspace ID to root node
	std::map<PHLWORKSPACE, std::unique_ptr<SBSPNode>> m_mWorkspaceRoots;

	// Helper methods
	SBSPNode* getNodeFromWindow(PHLWINDOW, SBSPNode* root);
	SBSPNode* findLargestLeafNode(SBSPNode* node);
	void splitNode(SBSPNode* node, PHLWINDOW newWindow);
	void applyNodeGeometry(PHLWINDOW window, const CBox& box);
	void applyTreeGeometry(SBSPNode* node);
	SBSPNode* removeWindowFromTree(SBSPNode* node, PHLWINDOW window, bool& found);
	CBox getWorkspaceBox(PHLWORKSPACE workspace);
};
