#pragma once

#include "axmol/axmol.h"
#include "CCBSequence.h"
#include "CCBSequenceProperty.h"
#include <string>
#include <vector>

namespace ccb {

// CCB 动画管理器（简化实现）
class CCBAnimationManager : public ax::Object
{
public:
    static CCBAnimationManager* create()
    {
        auto* ret = new CCBAnimationManager();
        ret->autorelease();
        return ret;
    }

    void setRootContainerSize(const ax::Size& size) { mRootContainerSize = size; }
    void setRootNode(ax::Node* pNode) { mRootNode = pNode; }
    ax::Node* getRootNode() { return mRootNode; }

    ax::Vector<CCBSequence*>& getSequences() { return mSequences; }
    int getAutoPlaySequenceId() { return mAutoPlaySequenceId; }
    void setAutoPlaySequenceId(int id) { mAutoPlaySequenceId = id; }

    int getSequenceId(const char* pName);
    const char* getLastCompletedSequenceName();
    void setLastCompletedSequenceName(const std::string& name) { mLastCompletedSequenceName = name; }

    void runAnimations(const char* pName);
    void runAnimationsForSequenceIdTweenDuration(int nSeqId, float fTweenDuration);

    void addNode(ax::Node* pNode, ax::Object* seqs) {}
    void moveAnimationsFromNode(ax::Node* from, ax::Node* to) {}

    void setDocumentControllerName(const std::string& name) { mDocumentControllerName = name; }

    void addDocumentCallbackName(const std::string& name) { mDocumentCallbackNames.push_back(name); }
    void addDocumentCallbackNode(ax::Node* node) { mDocumentCallbackNodes.pushBack(node); }

    bool jsControlled = false;
    std::vector<std::string> mDocumentCallbackNames;
    ax::Vector<ax::Node*> mDocumentCallbackNodes;

private:
    ax::Size mRootContainerSize;
    ax::Node* mRootNode = nullptr;
    ax::Vector<CCBSequence*> mSequences;
    int mAutoPlaySequenceId = -1;
    std::string mLastCompletedSequenceName;
    std::string mDocumentControllerName;
};

} // namespace ccb
