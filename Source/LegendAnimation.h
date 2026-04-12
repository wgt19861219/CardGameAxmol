#pragma once

#include "axmol/axmol.h"
#include "LegendAnimationFileInfo.h"

namespace ax {

class SpriteBatchNode;

class LegendAnimation : public Sprite
{
public:
    static LegendAnimation* create(const char* resource, double scale = 1.0);
    virtual ~LegendAnimation();

    bool setAction(const char* name, bool bRemoveQueue = true);
    void setNextAction(const char* actionName);
    void setLoop(bool val);
    void setActionElapsed(float elapsed);
    void setActionSpeeder(float speeder);
    bool isTerminated() const { return _isTerminated; }
    std::string getAniFileName() const { return _aniFileName; }

    virtual void update(float dt) override;

protected:
    LegendAnimation();
    bool init(LegendAnimationFileInfo* info, double scale);
    void onActionFinished();
    void applyFrame(const LegendAnimationFrame& frame);

    LegendAnimationFileInfo* _aniFileInfo = nullptr;
    std::string _aniFileName;

    // Batch rendering (matches original CCSpriteBatchNode architecture)
    SpriteBatchNode* _batchNode = nullptr;
    std::vector<Sprite*> _elementSprites;

    int _currentFrame = -1;
    std::string _currentActionName;
    const LegendAnimationAction* _currentAction = nullptr;
    std::string _nextActionName;
    bool _isLoop = false;
    float _curActionElapsed = 0;
    float _speeder = 1.0f;
    float _frameDuration = 0;
    bool _isTerminated = false;
};

// ---- LegendAnimationEffect (Start → Loop auto-switch) ----

class LegendAnimationEffect : public LegendAnimation
{
public:
    static LegendAnimationEffect* create(const char* resource);
    virtual ~LegendAnimationEffect();

    void setLoopAction(const char* actionName);
    void setStartAction(const char* actionName);

    virtual void onEnter() override;
    virtual void update(float dt) override;

protected:
    LegendAnimationEffect();

    std::string _startActionName = "Start";
    std::string _loopActionName = "Loop";
};

} // namespace ax
