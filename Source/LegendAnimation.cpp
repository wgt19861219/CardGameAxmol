#include "LegendAnimation.h"
#include "axmol/axmol.h"

namespace ax {

// ---- LegendAnimation ----

LegendAnimation::LegendAnimation()
{
}

LegendAnimation::~LegendAnimation()
{
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

    // Create child sprites for each element
    int count = (int)info->_elements.size();
    _childSprites.resize(count, nullptr);

    for (int i = 0; i < count; i++)
    {
        auto& ele = info->_elements[i];
        SpriteFrame* frame = info->getSpriteFrame(ele.resouceName.c_str());
        if (frame)
        {
            auto* child = Sprite::createWithSpriteFrame(frame);
            if (child)
            {
                child->setAnchorPoint(Vec2(0, 1));  // top-left origin
                addChild(child, i);
                child->setVisible(false);
                _childSprites[i] = child;
            }
        }
    }

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
    _currentFrame = 0;
    _curActionElapsed = 0;
    _frameDuration = 1.0f / action->fps;
    _isTerminated = false;

    if (bRemoveQueue)
        _nextActionName.clear();

    applyFrame(action->frames[0]);
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

    int newFrame = (int)(_curActionElapsed / _frameDuration);
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

    // Hide all children
    for (size_t i = 0; i < _childSprites.size(); i++)
    {
        if (_childSprites[i])
            _childSprites[i]->setVisible(false);
    }

    // Apply frame elements
    for (size_t i = 0; i < frame.elements.size(); i++)
    {
        const LegendAnimationFrameElement& felem = frame.elements[i];
        int idx = felem.index - 1;  // 1-based to 0-based
        if (idx >= 0 && idx < (int)_childSprites.size())
        {
            auto* child = _childSprites[idx];
            if (child)
            {
                child->setVisible(true);
                child->setOpacity(felem.alpha);

                // Apply affine transform
                const auto& t = felem.transform;
                child->setPosition(t.tx, -t.ty);  // flip Y for axmol coords
                child->setScaleX(t.a);
                child->setScaleY(t.d);
            }
        }
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

    // Start with "Start" action, then auto-switch to "Loop"
    if (!_loopActionName.empty())
    {
        setAction(_startActionName.c_str(), true);
        setNextAction(_loopActionName.c_str());
        setLoop(false);  // Start plays once
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
