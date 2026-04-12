#include "LegendAnimation.h"
#include "axmol/2d/SpriteBatchNode.h"
#include "axmol/axmol.h"

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
        AXLOGD("LegendAnimation::setAction: '{}' not found", name);
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
        return;

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
            return;
        }
    }

    if (newFrame != _currentFrame)
    {
        _currentFrame = newFrame;
        applyFrame(_currentAction->frames[_currentFrame]);
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

void LegendAnimation::applyFrame(const LegendAnimationFrame& frame)
{
    if (!_aniFileInfo) return;

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

        // Apply full affine transform via setAdditionalTransform.
        // Anchor is (0,0) so the base transform is identity,
        // making final = identity * additional = additional.
        // This matches original CCSprite::setTransform() behavior.
        child->setAdditionalTransform(felem.transform);
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
