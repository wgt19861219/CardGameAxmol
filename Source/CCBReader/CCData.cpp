#include "CCData.h"
#include <cstring>

namespace ccb {

CCData::CCData(unsigned char* pBytes, unsigned long nSize)
{
    if (!pBytes || nSize == 0)
    {
        m_pBytes = nullptr;
        m_nSize = 0;
        return;
    }
    m_nSize = nSize;
    m_pBytes = new unsigned char[m_nSize];
    memcpy(m_pBytes, pBytes, m_nSize);
}

CCData::CCData(CCData* pData)
{
    if (!pData || !pData->m_pBytes || pData->m_nSize == 0)
    {
        m_pBytes = nullptr;
        m_nSize = 0;
        return;
    }
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
