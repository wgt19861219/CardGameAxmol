#include "CCData.h"
#include <cstring>

namespace ccb {

CCData::CCData(unsigned char* pBytes, unsigned long nSize)
{
    m_nSize = nSize;
    m_pBytes = new unsigned char[m_nSize];
    memcpy(m_pBytes, pBytes, m_nSize);
}

CCData::CCData(CCData* pData)
{
    m_nSize = pData->m_nSize;
    m_pBytes = new unsigned char[m_nSize];
    memcpy(m_pBytes, pData->m_pBytes, m_nSize);
}

CCData::~CCData()
{
    delete[] m_pBytes;
    m_pBytes = nullptr;
}

} // namespace ccb
