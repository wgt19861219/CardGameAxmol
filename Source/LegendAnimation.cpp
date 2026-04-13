#include "LegendAnimation.h"
#include "axmol/2d/SpriteBatchNode.h"
#include "axmol/axmol.h"
#include "axmol/math/TransformUtils.h"

namespace ax {

// ---- LegendAnimation ----

LegendAnimation::LegendAnimation()
{
}

LegendAnimation::~LegendAnimation()
{
    AX_SAFE_RELEASE(_batchNode);
    AX_SAFE_RELEASE(_aniFileInfo);
}

LegendAnimation* LegendAnimation::create(const char* resource, double scale)
{
    auto* info = LegendAnimationFileInfo::getAniFileInfo(resource);
    if (!info || info->_elements.empty())
    {
        AXLOGD("LegendAnimation::create: failed to load: {}", resource);
        return nullptr;
    }

    auto* ret = new LegendAnimation();
    if (ret && ret->init(info, scale))
    {
        ret->autorelease();
        return ret;
    }
    delete ret;
    return nullptr;
}

bool LegendAnimation::init(LegendAnimationFileInfo* info, double scale)
{
    if (!Sprite::init())
        return false;

    _aniFileInfo = info;
    _aniFileInfo->retain();
    _aniFileName = info->_name;

    // Create child sprites for each element using SpriteBatchNode
    // (matches original architecture where all elements share one texture atlas)
    int count = (int)info->_elements.size();
    _elementSprites.resize(count, nullptr);

    Texture2D* texture = info->getTexture();
    if (!texture)
    {
        AXLOGW("LegendAnimation init: no texture for {}", info->_name);
        return false;
    }

    int spriteOk = 0, spriteFail = 0;
    for (int i = 0; i < count; i++)
    {
        auto& ele = info->_elements[i];
        SpriteFrame* frame = info->getSpriteFrame(ele.resouceName.c_str());
        if (frame)
        {
            auto* child = Sprite::createWithSpriteFrame(frame);
            if (child)
            {
                // Create batch node on first sprite (same texture for all)
                if (!_batchNode)
                {
                    _batchNode = SpriteBatchNode::createWithTexture(texture, count);
                    if (_batchNode)
                    {
                        _batchNode->retain();
                        // Match original: batch node scale matches the animation's scale factor
                        // (original: this->_batchNode->setScale(this->_aniFileInfo->_scalefactor))
                        _batchNode->setScale(_aniFileInfo->getScaleFactor());
                        addChild(_batchNode, 0);
                    }
                }

                // Match original: anchor (0,0) for direct transform application
                child->setAnchorPoint(Vec2(0, 0));
                child->setPosition(Vec2(0, 0));
                child->setVisible(false);
                child->setTag(i);

                if (_batchNode)
                    _batchNode->addChild(child);
                else
                    addChild(child, i);

                _elementSprites[i] = child;
                spriteOk++;
            }
            else
            {
                spriteFail++;
            }
        }
        else
        {
            spriteFail++;
            if (i < 3)
                AXLOGW("LegendAnimation init: sprite frame not found for '{}'", ele.resouceName);
        }
    }

    AXLOGW("LegendAnimation init: name={} elements={} sprites_ok={} sprites_fail={} actions={}",
           info->_name, count, spriteOk, spriteFail, info->_actions.size());
    if (_batchNode)
        AXLOGW("DIAG init: batchNode scale={:.4f}, scaleFactor={:.4f}",
               _batchNode->getScale(), info->getScaleFactor());

    setContentSize(Size(200, 200));
    scheduleUpdate();
    return true;
}

bool LegendAnimation::setAction(const char* name, bool bRemoveQueue)
{
    if (!_aniFileInfo) return false;

    const LegendAnimationAction* action = nullptr;
    for (size_t i = 0; i < _aniFileInfo->_actions.size(); i++)
    {
        if (_aniFileInfo->_actions[i].name == name)
        {
            action = &_aniFileInfo->_actions[i];
            break;
        }
    }

    if (!action || action->frames.empty())
    {
        AXLOGW("LegendAnimation::setAction: '{}' not found in '{}' (has {} actions: {})",
               name, _aniFileName, _aniFileInfo->_actions.size(),
               _aniFileInfo->_actions.empty() ? "" : _aniFileInfo->_actions[0].name);
        return false;
    }

    _currentAction = action;
    _currentActionName = name;
    _currentFrame = -1;
    _curActionElapsed = 0;
    _frameDuration = 1.0f / action->fps;
    _isTerminated = false;

    if (bRemoveQueue)
        _nextActionName.clear();

    // Apply first frame
    applyFrame(action->frames[0]);
    _currentFrame = 0;
    return true;
}

void LegendAnimation::setNextAction(const char* actionName)
{
    _nextActionName = actionName;
}

void LegendAnimation::setLoop(bool val)
{
    _isLoop = val;
}

void LegendAnimation::setActionElapsed(float elapsed)
{
    _curActionElapsed = elapsed;
}

void LegendAnimation::setActionSpeeder(float speeder)
{
    _speeder = speeder;
}

void LegendAnimation::update(float dt)
{
    Sprite::update(dt);

    if (!_currentAction || _frameDuration <= 0)
    {
        // Still update child effects even if no action
        for (int kk = (int)_effectArray.size() - 1; kk >= 0; kk--)
        {
            auto* eff = _effectArray.at(kk);
            eff->update(dt);
            if (eff->isTerminated())
            {
                _effectArray.erase(kk);
                removeChild(eff, true);
            }
        }
        return;
    }

    _curActionElapsed += dt * _speeder;

    int newFrame = (int)(_curActionElapsed * _currentAction->fps);
    int totalFrames = (int)_currentAction->frames.size();

    if (newFrame >= totalFrames)
    {
        if (_isLoop)
        {
            _curActionElapsed = 0;
            newFrame = 0;
        }
        else
        {
            newFrame = totalFrames - 1;
            if (!_isTerminated)
            {
                _isTerminated = true;
                onActionFinished();
            }
            // Update child effects
            for (int kk = (int)_effectArray.size() - 1; kk >= 0; kk--)
            {
                auto* eff = _effectArray.at(kk);
                eff->update(dt);
                if (eff->isTerminated())
                {
                    _effectArray.erase(kk);
                    removeChild(eff, true);
                }
            }
            return;
        }
    }

    if (newFrame != _currentFrame)
    {
        // Process events for all frames between _currentFrame and newFrame
        // (matches original: for i=_currentFrame+1 to calcFrame, process events)
        int startFrame = (_currentFrame < 0) ? 0 : _currentFrame + 1;
        for (int i = startFrame; i <= newFrame && i < totalFrames; i++)
        {
            const LegendAnimationFrame& frame = _currentAction->frames[i];
            for (size_t j = 0; j < frame.events.size(); j++)
            {
                const LegendAnimationEvent& evt = frame.events[j];
                if (evt.type == LegendAnimationEvent::EVENT_ADD_EFFECT)
                {
                    addEffect(evt.arg.c_str(), evt.transform, evt.zorder);
                }
                else if (evt.type == LegendAnimationEvent::EVENT_REMOVE_EFFECT)
                {
                    removeEffectWithName(evt.arg.c_str());
                }
            }
        }

        _currentFrame = newFrame;
        applyFrame(_currentAction->frames[_currentFrame]);
    }

    // Update child effects (matches original: iterate _effectArray backwards)
    for (int kk = (int)_effectArray.size() - 1; kk >= 0; kk--)
    {
        auto* eff = _effectArray.at(kk);
        eff->update(dt);
        if (eff->isTerminated())
        {
            _effectArray.erase(kk);
            removeChild(eff, true);
        }
    }
}

void LegendAnimation::onActionFinished()
{
    if (!_nextActionName.empty())
    {
        std::string next = _nextActionName;
        _nextActionName.clear();
        setAction(next.c_str(), true);
        _isLoop = true;
    }
}

// ---- Effect management (matches original LegendAnimation) ----

int LegendAnimation::addEffect(const char* resName)
{
    return addEffect(resName, AffineTransformMakeIdentity(), 1);
}

int LegendAnimation::addEffect(const char* resName, const AffineTransform& mat, int zorder)
{
    auto* eff = LegendAnimationEffect::create(resName);
    if (!eff)
    {
        AXLOGW("LegendAnimation::addEffect: failed to create effect '{}'", resName);
        return -1;
    }

    // Match original: eff->setTransform(mat)
    // In original cocos2d-x, CCSprite::setTransform() directly sets the node transform.
    // In Axmol, we use setNodeToParentTransform to achieve the same effect.
    Mat4 transformMat;
    CGAffineToGL(mat, transformMat.m);
    eff->setNodeToParentTransform(transformMat);

    this->addChild(eff, zorder);
    _effectArray.pushBack(eff);
    eff->setTag(_curEffectTag++);

    return eff->getTag();
}

int LegendAnimation::addEffect(const char* resName, Vec2 pos, int zorder)
{
    AffineTransform mt = AffineTransformMakeIdentity();
    mt.tx = pos.x;
    mt.ty = pos.y;
    return addEffect(resName, mt, zorder);
}

int LegendAnimation::addEffect(const char* resName, int zorder)
{
    return addEffect(resName, AffineTransformMakeIdentity(), zorder);
}

void LegendAnimation::removeEffectWithID(int eid)
{
    for (auto& eff : _effectArray)
    {
        if (eff->getTag() == eid)
        {
            _effectArray.eraseObject(eff);
            removeChild(eff, true);
            return;
        }
    }
}

void LegendAnimation::removeEffectWithName(const char* name)
{
    for (auto& eff : _effectArray)
    {
        if (eff->getAniFileName() == name)
        {
            _effectArray.eraseObject(eff);
            removeChild(eff, true);
            return;
        }
    }
}

void LegendAnimation::applyFrame(const LegendAnimationFrame& frame)
{
    if (!_aniFileInfo) return;

    // DIAG: 打印前2帧的前2个元素的变换
    static int diagFrameCount = 0;
    bool doDiag = (diagFrameCount < 2);
    diagFrameCount++;

    // Hide all element sprites
    for (size_t i = 0; i < _elementSprites.size(); i++)
    {
        if (_elementSprites[i])
            _elementSprites[i]->setVisible(false);
    }

    // Apply frame elements with FULL affine transform
    // (matches original pSpr->setTransform(felem.transform))
    bool needReorder = false;
    for (size_t i = 0; i < frame.elements.size(); i++)
    {
        const LegendAnimationFrameElement& felem = frame.elements[i];
        int idx = felem.index - 1;  // 1-based to 0-based
        if (idx < 0 || idx >= (int)_elementSprites.size())
            continue;

        auto* child = _elementSprites[idx];
        if (!child)
            continue;

        child->setVisible(true);
        child->setOpacity(felem.alpha);

        // Check if z-order needs updating
        if (child->getLocalZOrder() != (int)i)
            needReorder = true;
        child->setLocalZOrder((int)i);

        // Apply full affine transform via setNodeToParentTransform.
        // This DIRECTLY REPLACES the node's transform matrix,
        // matching the original CCSprite::setTransform() behavior.
        // IMPORTANT: Do NOT use setAdditionalTransform — it MULTIPLIES
        // the node's existing transform, causing garbled rendering.
        Mat4 transformMat;
        CGAffineToGL(felem.transform, transformMat.m);
        child->setNodeToParentTransform(transformMat);

        // DIAG: 打印前2帧的前2个元素
        if (doDiag && i < 2) {
            AXLOGW("DIAG applyFrame: ani={} action={} frame={} elem={} alpha={} pos=({:.1f},{:.1f})",
                   _aniFileName, _currentActionName, _currentFrame, idx, (int)felem.alpha,
                   transformMat.m[12], transformMat.m[13]);
            AXLOGW("DIAG applyFrame: m=[{:.4f},{:.4f},{:.4f},{:.4f}] anchor=({:.1f},{:.1f}) visible={}",
                   transformMat.m[0], transformMat.m[1], transformMat.m[4], transformMat.m[5],
                   child->getAnchorPoint().x, child->getAnchorPoint().y, child->isVisible());
        }
    }

    // Update batch rendering order if needed
    if (_batchNode && needReorder)
    {
        _batchNode->reorderBatch(needReorder);
    }
}

// ---- LegendAnimationEffect ----

LegendAnimationEffect::LegendAnimationEffect()
{
}

LegendAnimationEffect::~LegendAnimationEffect()
{
}

LegendAnimationEffect* LegendAnimationEffect::create(const char* resource)
{
    // No prefix — LegendAnimationFileInfo searches both anim/ and anim/effect/ paths
    auto* info = LegendAnimationFileInfo::getAniFileInfo(resource);
    if (!info || info->_elements.empty())
        return nullptr;

    auto* ret = new LegendAnimationEffect();
    if (ret && ret->init(info, 1.0))
    {
        ret->autorelease();

        // Auto-detect if Loop action exists
        for (size_t i = 0; i < info->_actions.size(); i++)
        {
            if (info->_actions[i].name == "Loop")
            {
                ret->_loopActionName = "Loop";
                break;
            }
        }

        return ret;
    }
    delete ret;
    return nullptr;
}

void LegendAnimationEffect::setLoopAction(const char* actionName)
{
    _loopActionName = actionName;
}

void LegendAnimationEffect::setStartAction(const char* actionName)
{
    _startActionName = actionName;
}

void LegendAnimationEffect::onEnter()
{
    LegendAnimation::onEnter();

    if (!_loopActionName.empty())
    {
        setAction(_startActionName.c_str(), true);
        setNextAction(_loopActionName.c_str());
        setLoop(false);
    }
    else
    {
        setAction(_startActionName.c_str(), true);
        setLoop(true);
    }
}

void LegendAnimationEffect::update(float dt)
{
    LegendAnimation::update(dt);
}

} // namespace ax
