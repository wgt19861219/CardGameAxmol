#include "CCBAnimationManager.h"

namespace ccb {

int CCBAnimationManager::getSequenceId(const char* pName)
{
    if (!pName) return -1;
    for (auto& seq : mSequences)
    {
        if (seq && seq->getName() && strcmp(seq->getName(), pName) == 0)
            return seq->getSequenceId();
    }
    return -1;
}

const char* CCBAnimationManager::getLastCompletedSequenceName()
{
    return mLastCompletedSequenceName.c_str();
}

void CCBAnimationManager::runAnimations(const char* pName)
{
    int seqId = getSequenceId(pName);
    if (seqId >= 0)
        runAnimationsForSequenceIdTweenDuration(seqId, 0);
}

void CCBAnimationManager::runAnimationsForSequenceIdTweenDuration(int nSeqId, float fTweenDuration)
{
    AXLOGD("CCBAnimationManager::runAnimationsForSequenceIdTweenDuration({})", nSeqId);
}

} // namespace ccb
