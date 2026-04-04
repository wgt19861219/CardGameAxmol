#pragma once

#include "axmol/axmol.h"
#include <spine/spine-axmol.h>
#include <spine/SkeletonAnimation.h>
#include <string>
#include <map>
#include "GameAnimation.h"

class SpineEventListener
{
public:
    virtual void onSpineAnimationStart(int trackIndex, const std::string& animationName) {}
    virtual void onSpineAnimationEnd(int trackIndex, const std::string& animationName) {}
    virtual void onSpineAnimationComplete(int trackIndex, const std::string& animationName, int loopCount) {}
    virtual void onSpineAnimationEvent(int trackIndex, const std::string& animationName, spine::Event* event) {}
};

class SpineContainer : public spine::SkeletonAnimation, public GameAnimation
{
public:
    SpineContainer();
    ~SpineContainer();

    static SpineContainer* create(const char* path, const char* name, float scale = 1.0f);

    void runAnimation(int trackIndex, const char* name, int loopTimes = 1, float delay = 0);

    void setListener(SpineEventListener* eventListener);
    void registerLuaListener(int listener);
    void unregisterLuaListener();

    void stopAllAnimations();
    void stopAnimationByIndex(int trackIndex);

    bool setAction(const char* name, bool bRemoveQueue) override;

    int addEffect(const char* resName);
    int addEffect(const char* resName, const ax::AffineTransform& mat, int zorder);
    int addEffect(const char* resName, ax::Vec2 pos, int zorder);
    int addEffect(const char* name, int zorder);
    void clearActionSequence();
    void interruptSound();
    void onActionFinished();
    void removeEffectWithID(int eid);
    void removeEffectWithName(const char* effectName);
    void setColor(ax::Color32 clr);

    bool setComponent(const char* param1, const char* param2) { return true; }
    bool setComponent(int index, const char* lpszName) { return true; }
    void setNextAction(const char* actionName);
    void setOpacity(unsigned char param1);
    void tint(float r, float g, float b);
    void update(float dt, bool isAuto);
    void useDefaultShader();
    void useShader(const char* shaderName);
    void setActionElapsed(float elapsed) {}
    void setActionSpeeder(float speeder) {}
    void setLoop(bool val) { m_bIsLoop = val; }

    // override base update
    void update(float dt) override { SkeletonAnimation::update(dt); }

protected:
    struct SAnimationInfo
    {
        std::string aniName;
        unsigned int trackIndex;
        int loopTimes;

        SAnimationInfo(const std::string& name, unsigned int index, int times)
            : aniName(name), trackIndex(index), loopTimes(times)
        {}
    };

    void onReceiveStartEventListener(int trackIndex, const std::string& animationName);
    void onReceiveEndEventListener(int trackIndex, const std::string& animationName);
    void onReceiveCompleteEventListener(int trackIndex, const std::string& animationName, int loopCount);
    void onReceiveEventListener(int trackIndex, const std::string& animationName, spine::Event* event);

    typedef std::map<std::string, SAnimationInfo> AnimationTrackMap;

    SAnimationInfo* getAnimationInfo(unsigned int trackIndex)
    {
        for (auto& pair : m_mapTrack)
        {
            if (pair.second.trackIndex == trackIndex)
                return &pair.second;
        }
        return nullptr;
    }

    SpineEventListener* m_pEventListener;
    int m_iLuaListener;

    AnimationTrackMap m_mapTrack;
    ax::Vector<ax::Node*> _effectArray;
    std::vector<std::string> _actionQueue;
    bool m_bIsLoop;
    std::string m_sCurrAniName;
    int _curSoundId;
    bool _isSoundPlay;
    int m_iCurrEffectTag;
};
