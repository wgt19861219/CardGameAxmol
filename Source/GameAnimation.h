#pragma once

#include "axmol/axmol.h"

enum AnimationType
{
    Type_LegendAnimation,
    Type_Spine,
    Type_DragonBone
};

class GameAnimation
{
public:
    GameAnimation(AnimationType aniType = Type_LegendAnimation);
    virtual ~GameAnimation();

    static GameAnimation* create(const char* resource, double scale = 1.0, AnimationType aniType = Type_LegendAnimation);

    virtual bool setAction(const char* name, bool bRemoveQueue) = 0;

    AnimationType mAniType;
};
