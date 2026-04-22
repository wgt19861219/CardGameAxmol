#pragma once

#include "axmol/axmol.h"

class ClipRectNode : public ax::Node
{
public:
    static ClipRectNode* create();

    void setClipRect(const ax::Rect& rect);
    const ax::Rect& getClipRect() const;

    void visit(ax::Renderer* renderer, const ax::Mat4& parentTransform, uint32_t parentFlags) override;

protected:
    ClipRectNode();
    virtual ~ClipRectNode() = default;
    bool init() override;

private:
    ax::Rect _clipRect;
};
