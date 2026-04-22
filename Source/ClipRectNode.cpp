#include "ClipRectNode.h"
#include "axmol/renderer/Renderer.h"
#include "axmol/renderer/CallbackCommand.h"
#include "axmol/base/Director.h"
#include "axmol/platform/RenderView.h"

#if (AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID)
#    include <GLES2/gl2.h>
#else
#    include "axmol/rhi/opengl/GLHeaders.h"
#endif

ClipRectNode::ClipRectNode() : _clipRect(ax::Rect::ZERO) {}

ClipRectNode* ClipRectNode::create()
{
    ClipRectNode* ret = new ClipRectNode();
    if (ret->init())
    {
        ret->autorelease();
    }
    else
    {
        AX_SAFE_DELETE(ret);
    }
    return ret;
}

bool ClipRectNode::init()
{
    return Node::init();
}

void ClipRectNode::setClipRect(const ax::Rect& rect)
{
    _clipRect = rect;
}

const ax::Rect& ClipRectNode::getClipRect() const
{
    return _clipRect;
}

void ClipRectNode::visit(ax::Renderer* renderer, const ax::Mat4& parentTransform, uint32_t parentFlags)
{
    if (!_visible)
        return;

    uint32_t flags = processParentFlags(parentTransform, parentFlags);

    // _clipRect 是局部坐标（相对于父节点），用 _modelViewTransform 转换到 GL 坐标
    ax::Vec3 bottomLeft(_clipRect.origin.x, _clipRect.origin.y, 0.0f);
    ax::Vec3 topRight(_clipRect.origin.x + _clipRect.size.width,
                      _clipRect.origin.y + _clipRect.size.height, 0.0f);

    _modelViewTransform.transformPoint(&bottomLeft);
    _modelViewTransform.transformPoint(&topRight);

    auto view      = _director->getRenderView();
    auto viewPort  = view->getViewportRect();
    float scaleX   = view->getScaleX();
    float scaleY   = view->getScaleY();

    float x = bottomLeft.x * scaleX + viewPort.origin.x;
    float y = bottomLeft.y * scaleY + viewPort.origin.y;
    float w = (topRight.x - bottomLeft.x) * scaleX;
    float h = (topRight.y - bottomLeft.y) * scaleY;

    if (w < 0) { x += w; w = -w; }
    if (h < 0) { y += h; h = -h; }

    // scissor 无效则跳过裁剪，正常渲染
    bool hasScissor = (w > 0 && h > 0);

    _director->pushMatrix(ax::MATRIX_STACK_TYPE::MATRIX_STACK_MODELVIEW);
    _director->loadMatrix(ax::MATRIX_STACK_TYPE::MATRIX_STACK_MODELVIEW, _modelViewTransform);

    auto* groupCommand = renderer->getNextGroupCommand();
    groupCommand->init(_globalZOrder);
    renderer->addCommand(groupCommand);
    renderer->pushGroup(groupCommand->getRenderQueueID());

    bool wasScissorEnabled = false;
    GLint oldScissorRect[4] = {};
    if (hasScissor)
    {
        wasScissorEnabled = glIsEnabled(GL_SCISSOR_TEST) != GL_FALSE;
        if (wasScissorEnabled)
            glGetIntegerv(GL_SCISSOR_BOX, oldScissorRect);

        auto beforeCmd = renderer->nextCallbackCommand();
        beforeCmd->init(_globalZOrder);
        beforeCmd->func = [x, y, w, h]() {
            glEnable(GL_SCISSOR_TEST);
            glScissor(static_cast<GLint>(x), static_cast<GLint>(y),
                      static_cast<GLsizei>(w), static_cast<GLsizei>(h));
        };
        renderer->addCommand(beforeCmd);
    }

    // 正常 visit children
    bool visibleByCamera = isVisitableByVisitingCamera();
    if (!_children.empty())
    {
        sortAllChildren();
        int i = 0;
        for (int size = static_cast<int>(_children.size()); i < size; ++i)
        {
            auto node = _children.at(i);
            if (node && node->getLocalZOrder() < 0)
                node->visit(renderer, _modelViewTransform, flags);
            else
                break;
        }
        if (visibleByCamera)
            this->draw(renderer, _modelViewTransform, flags);
        for (auto it = _children.cbegin() + i, itCend = _children.cend(); it != itCend; ++it)
            (*it)->visit(renderer, _modelViewTransform, flags);
    }
    else if (visibleByCamera)
    {
        this->draw(renderer, _modelViewTransform, flags);
    }

    if (hasScissor)
    {
        auto afterCmd = renderer->nextCallbackCommand();
        afterCmd->init(_globalZOrder);
        afterCmd->func = [wasScissorEnabled, oldScissorRect]() {
            if (wasScissorEnabled)
            {
                glEnable(GL_SCISSOR_TEST);
                glScissor(oldScissorRect[0], oldScissorRect[1],
                          oldScissorRect[2], oldScissorRect[3]);
            }
            else
            {
                glDisable(GL_SCISSOR_TEST);
            }
        };
        renderer->addCommand(afterCmd);
    }

    renderer->popGroup();
    _director->popMatrix(ax::MATRIX_STACK_TYPE::MATRIX_STACK_MODELVIEW);
}
