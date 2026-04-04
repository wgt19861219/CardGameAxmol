#include "CCBKeyframe.h"

namespace ccb {

CCBKeyframe::CCBKeyframe() = default;

CCBKeyframe::~CCBKeyframe()
{
    AX_SAFE_RELEASE_NULL(mValue);
}

void CCBKeyframe::setValue(ax::Object* pValue)
{
    AX_SAFE_RELEASE(mValue);
    mValue = pValue;
    AX_SAFE_RETAIN(mValue);
}

} // namespace ccb
