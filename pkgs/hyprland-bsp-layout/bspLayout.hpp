#pragma once

#include <hyprland/src/layout/algorithm/TiledAlgorithm.hpp>
#include <memory>

enum class SplitDirection {
	HORIZONTAL,
	VERTICAL
};

struct SBSPNode {
	bool isLeaf = true;
	SP<Layout::ITarget> target = nullptr;

	// For non-leaf nodes
	SplitDirection splitDir;
	std::unique_ptr<SBSPNode> left;
	std::unique_ptr<SBSPNode> right;
	float splitRatio = 0.5f;

	// Geometry
	CBox box;

	SBSPNode() = default;
	SBSPNode(SP<Layout::ITarget> t) : target(t) {}
};

class CBSPAlgorithm : public Layout::ITiledAlgorithm {
public:
	CBSPAlgorithm() = default;
	virtual ~CBSPAlgorithm() = default;

	// IModeAlgorithm
	virtual void newTarget(SP<Layout::ITarget> target) override;
	virtual void movedTarget(SP<Layout::ITarget> target, std::optional<Vector2D> focalPoint = std::nullopt) override;
	virtual void removeTarget(SP<Layout::ITarget> target) override;
	virtual void resizeTarget(const Vector2D& delta, SP<Layout::ITarget> target, Layout::eRectCorner corner = Layout::CORNER_NONE) override;
	virtual void recalculate() override;
	virtual void swapTargets(SP<Layout::ITarget> a, SP<Layout::ITarget> b) override;
	virtual void moveTargetInDirection(SP<Layout::ITarget> t, Math::eDirection dir, bool silent) override;

	// ITiledAlgorithm
	virtual SP<Layout::ITarget> getNextCandidate(SP<Layout::ITarget> old) override;

	// Optional overrides
	virtual std::expected<void, std::string> layoutMsg(const std::string_view& sv) override;
	virtual std::optional<Vector2D> predictSizeForNewTarget() override;

private:
	std::unique_ptr<SBSPNode> m_root;

	// Helper methods
	SBSPNode* getNodeFromTarget(SP<Layout::ITarget> target, SBSPNode* root);
	SBSPNode* getParentNode(SBSPNode* child, SBSPNode* root);
	SBSPNode* findLargestLeafNode(SBSPNode* node);
	void splitNode(SBSPNode* node, SP<Layout::ITarget> newTarget);
	void applyTreeGeometry(SBSPNode* node);
	void recalculateTreeBoxes(SBSPNode* node);
	SBSPNode* removeTargetFromTree(SBSPNode* node, SP<Layout::ITarget> target, bool& found);
	void collectLeaves(SBSPNode* node, std::vector<SBSPNode*>& leaves);
	SBSPNode* findAdjacentLeaf(SBSPNode* target, Math::eDirection dir, SBSPNode* root);
};
