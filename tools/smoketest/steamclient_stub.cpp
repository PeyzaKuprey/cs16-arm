// steamclient_stub.cpp — minimal SteamClient012 backend for qemu-user smoke
// tests (and CI) of the ReHLDS libsteam_api shim, where Valve's real
// steamclient.so cannot run (anti-emulation futex robust_list check).
//
// Implements exactly the call sequence libsteam_api's SteamGameServer_Init
// performs: SetLocalIPBinding → CreateLocalUser(&pipe, GameServer) →
// GetISteamGameServer/Utils/Networking/Stats/HTTP/Apps → InitGameServer,
// plus the callback-poll exports (Steam_BGetCallback family) and
// Breakpad_SteamSetAppID the shim resolves opportunistically.
//
// Signatures match the ReHLDS-vendored Steamworks SDK in
// rehlds/public/steam/ (the old 1.34-era interfaces), not the modern SDK.
//
// Build (aarch64):
//   aarch64-buildroot-linux-gnu-g++ -std=c++11 -shared -fPIC -O1
//     -I<rehlds>/rehlds/public/steam -I<rehlds>/dep/libsteam_api/stub_include
//     steamclient_stub.cpp -o steamclient_stub.so
#include <cstdint>
#include <cstdio>
#include <cstring>

// uint8/16/32/64 typedefs that steamtypes.h expects predefined
// (same include order libsteam_api.cpp uses).
#include "common.h"

#include "isteamclient.h"
#include "isteamgameserver.h"
#include "isteamuser.h"
#include "isteamutils.h"
#include "isteamnetworking.h"
#include "isteamgameserverstats.h"
#include "isteamapps.h"
#include "isteamhttp.h"

namespace {

constexpr HSteamPipe kStubPipe = 7;
constexpr HSteamUser kStubUser = 8;

class SteamGameServerStub;
class SteamUtilsStub;
class SteamNetworkingStub;
class SteamGameServerStatsStub;
class SteamAppsStub;
class SteamHTTPStub;

// ─── ISteamClient012 (as vendored) ──────────────────────────────────────────
class SteamClientStub : public ISteamClient {
public:
	HSteamPipe CreateSteamPipe() override { return kStubPipe; }
	bool BReleaseSteamPipe(HSteamPipe hSteamPipe) override { return true; }
	HSteamUser ConnectToGlobalUser(HSteamPipe hSteamPipe) override { return kStubUser; }
	HSteamUser CreateLocalUser(HSteamPipe *phSteamPipe, EAccountType eAccountType) override {
		if (phSteamPipe) *phSteamPipe = kStubPipe;
		return kStubUser;
	}
	void ReleaseUser(HSteamPipe hSteamPipe, HSteamUser hUser) override {}
	ISteamUser *GetISteamUser(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override;
	ISteamGameServer *GetISteamGameServer(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override;
	void SetLocalIPBinding(uint32 unIP, uint16 usPort) override {}
	ISteamFriends *GetISteamFriends(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
	ISteamUtils *GetISteamUtils(HSteamPipe hSteamPipe, const char *pchVersion) override;
	ISteamMatchmaking *GetISteamMatchmaking(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
	ISteamMatchmakingServers *GetISteamMatchmakingServers(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
	void *GetISteamGenericInterface(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
	ISteamUserStats *GetISteamUserStats(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
	ISteamGameServerStats *GetISteamGameServerStats(HSteamUser hSteamuser, HSteamPipe hSteamPipe, const char *pchVersion) override;
	ISteamApps *GetISteamApps(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override;
	ISteamNetworking *GetISteamNetworking(HSteamUser hSteamUser, HSteamPipe hSteamPipe, const char *pchVersion) override;
	ISteamRemoteStorage *GetISteamRemoteStorage(HSteamUser hSteamuser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
	ISteamScreenshots *GetISteamScreenshots(HSteamUser hSteamuser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
	void RunFrame() override {}
	uint32 GetIPCCallCount() override { return 0; }
	void SetWarningMessageHook(SteamAPIWarningMessageHook_t pFunction) override {}
	bool BShutdownIfAllPipesClosed() override { return false; }
	ISteamHTTP *GetISteamHTTP(HSteamUser hSteamuser, HSteamPipe hSteamPipe, const char *pchVersion) override;
	ISteamUnifiedMessages *GetISteamUnifiedMessages(HSteamUser hSteamuser, HSteamPipe hSteamPipe, const char *pchVersion) override { return nullptr; }
};

// ─── ISteamGameServer011 (as vendored) ──────────────────────────────────────
class SteamGameServerStub : public ISteamGameServer {
public:
	bool InitGameServer(uint32 unIP, uint16 usGamePort, uint16 usQueryPort, uint32 unFlags, AppId_t nGameAppId, const char *pchVersionString) override { return true; }
	void SetProduct(const char *pszProduct) override {}
	void SetGameDescription(const char *pszGameDescription) override {}
	void SetModDir(const char *pszModDir) override {}
	void SetDedicatedServer(bool bDedicated) override {}
	void LogOn(const char *pszAccountName, const char *pszPassword) override {}
	void LogOnAnonymous() override {}
	void LogOff() override {}
	bool BLoggedOn() override { return true; }
	bool BSecure() override { return false; }
	CSteamID GetSteamID() override { return CSteamID(); }
	bool WasRestartRequested() override { return false; }
	void SetMaxPlayerCount(int cPlayersMax) override {}
	void SetBotPlayerCount(int cBotplayers) override {}
	void SetServerName(const char *pszServerName) override {}
	void SetMapName(const char *pszMapName) override {}
	void SetPasswordProtected(bool bPasswordProtected) override {}
	void SetSpectatorPort(uint16 unSpectatorPort) override {}
	void SetSpectatorServerName(const char *pszSpectatorServerName) override {}
	void ClearAllKeyValues() override {}
	void SetKeyValue(const char *pKey, const char *pValue) override {}
	void SetGameTags(const char *pchGameTags) override {}
	void SetGameData(const char *pchGameData) override {}
	void SetRegion(const char *pszRegion) override {}
	bool SendUserConnectAndAuthenticate(uint32 unIPClient, const void *pvAuthBlob, uint32 cubAuthBlobSize, CSteamID *pSteamIDUser) override { return false; }
	CSteamID CreateUnauthenticatedUserConnection() override { return CSteamID(); }
	void SendUserDisconnect(CSteamID steamIDUser) override {}
	bool BUpdateUserData(CSteamID steamIDUser, const char *pchPlayerName, uint32 uScore) override { return false; }
	HAuthTicket GetAuthSessionTicket(void *pTicket, int cbMaxTicket, uint32 *pcbTicket) override { if (pcbTicket) *pcbTicket = 0; return 0; }
	EBeginAuthSessionResult BeginAuthSession(const void *pAuthTicket, int cbAuthTicket, CSteamID steamID) override { return k_EBeginAuthSessionResultInvalidTicket; }
	void EndAuthSession(CSteamID steamID) override {}
	void CancelAuthTicket(HAuthTicket hAuthTicket) override {}
	EUserHasLicenseForAppResult UserHasLicenseForApp(CSteamID steamID, AppId_t appID) override { return k_EUserHasLicenseResultNoAuth; }
	bool RequestUserGroupStatus(CSteamID steamIDUser, CSteamID steamIDGroup) override { return false; }
	void GetGameplayStats() override {}
	SteamAPICall_t GetServerReputation() override { return 0; }
	uint32 GetPublicIP() override { return 0; }
	bool HandleIncomingPacket(const void *pData, int cbData, uint32 srcIP, uint16 srcPort) override { return false; }
	int GetNextOutgoingPacket(void *pOut, int cbMaxOut, uint32 *pNetAdr, uint16 *pPort) override { return 0; }
	void EnableHeartbeats(bool bActive) override {}
	void SetHeartbeatInterval(int iHeartbeatInterval) override {}
	void ForceHeartbeat() override {}
	SteamAPICall_t AssociateWithClan(CSteamID steamIDClan) override { return 0; }
	SteamAPICall_t ComputeNewPlayerCompatibility(CSteamID steamIDNewPlayer) override { return 0; }
};

// ─── ISteamUtils005 (as vendored) ───────────────────────────────────────────
class SteamUtilsStub : public ISteamUtils {
public:
	uint32 GetSecondsSinceAppActive() override { return 0; }
	uint32 GetSecondsSinceComputerActive() override { return 0; }
	EUniverse GetConnectedUniverse() override { return k_EUniversePublic; }
	uint32 GetServerRealTime() override { return 0; }
	const char *GetIPCountry() override { return "ZZ"; }
	bool GetImageSize(int iImage, uint32 *pnWidth, uint32 *pnHeight) override { return false; }
	bool GetImageRGBA(int iImage, uint8 *pubDest, int nDestBufferSize) override { return false; }
	bool GetCSERIPPort(uint32 *unIP, uint16 *usPort) override { return false; }
	uint8 GetCurrentBatteryPower() override { return 255; }
	uint32 GetAppID() override { return 10; }
	void SetOverlayNotificationPosition(ENotificationPosition eNotificationPosition) override {}
	bool IsAPICallCompleted(SteamAPICall_t hSteamAPICall, bool *pbFailed) override { return false; }
	ESteamAPICallFailure GetAPICallFailureReason(SteamAPICall_t hSteamAPICall) override { return k_ESteamAPICallFailureNone; }
	bool GetAPICallResult(SteamAPICall_t hSteamAPICall, void *pCallback, int cubCallback, int iCallbackExpected, bool *pbFailed) override { return false; }
	void RunFrame() override {}
	uint32 GetIPCCallCount() override { return 0; }
	void SetWarningMessageHook(SteamAPIWarningMessageHook_t pFunction) override {}
	bool IsOverlayEnabled() override { return false; }
	bool BOverlayNeedsPresent() override { return false; }
	SteamAPICall_t CheckFileSignature(const char *szFileName) override { return 0; }
	bool ShowGamepadTextInput(EGamepadTextInputMode eInputMode, EGamepadTextInputLineMode eLineInputMode, const char *pchDescription, uint32 unCharMax) override { return false; }
	uint32 GetEnteredGamepadTextLength() override { return 0; }
	bool GetEnteredGamepadTextInput(char *pchText, uint32 cchText) override { return false; }
	const char *GetSteamUILanguage() override { return "english"; }
};

// ─── ISteamNetworking005 (as vendored) ──────────────────────────────────────
class SteamNetworkingStub : public ISteamNetworking {
public:
	bool SendP2PPacket(CSteamID steamIDRemote, const void *pubData, uint32 cubData, EP2PSend eP2PSendType, int nChannel) override { return false; }
	bool IsP2PPacketAvailable(uint32 *pcubMsgSize, int nChannel) override { return false; }
	bool ReadP2PPacket(void *pubDest, uint32 cubDest, uint32 *pcubMsgSize, CSteamID *psteamIDRemote, int nChannel) override { return false; }
	bool AcceptP2PSessionWithUser(CSteamID steamIDRemote) override { return false; }
	bool CloseP2PSessionWithUser(CSteamID steamIDRemote) override { return false; }
	bool CloseP2PChannelWithUser(CSteamID steamIDRemote, int nChannel) override { return false; }
	bool GetP2PSessionState(CSteamID steamIDRemote, P2PSessionState_t *pConnectionState) override { return false; }
	bool AllowP2PPacketRelay(bool bAllow) override { return false; }
	SNetListenSocket_t CreateListenSocket(int nVirtualP2PPort, uint32 nIP, uint16 nPort, bool bAllowUseOfPacketRelay) override { return 0; }
	SNetSocket_t CreateP2PConnectionSocket(CSteamID steamIDTarget, int nVirtualPort, int nTimeoutSec, bool bAllowUseOfPacketRelay) override { return 0; }
	SNetSocket_t CreateConnectionSocket(uint32 nIP, uint16 nPort, int nTimeoutSec) override { return 0; }
	bool DestroySocket(SNetSocket_t hSocket, bool bNotifyRemoteEnd) override { return false; }
	bool DestroyListenSocket(SNetListenSocket_t hSocket, bool bNotifyRemoteEnd) override { return false; }
	bool SendDataOnSocket(SNetSocket_t hSocket, void *pubData, uint32 cubData, bool bReliable) override { return false; }
	bool IsDataAvailableOnSocket(SNetSocket_t hSocket, uint32 *pcubMsgSize) override { return false; }
	bool RetrieveDataFromSocket(SNetSocket_t hSocket, void *pubDest, uint32 cubDest, uint32 *pcubMsgSize) override { return false; }
	bool IsDataAvailable(SNetListenSocket_t hListenSocket, uint32 *pcubMsgSize, SNetSocket_t *phSocket) override { return false; }
	bool RetrieveData(SNetListenSocket_t hListenSocket, void *pubDest, uint32 cubDest, uint32 *pcubMsgSize, SNetSocket_t *phSocket) override { return false; }
	bool GetSocketInfo(SNetSocket_t hSocket, CSteamID *pSteamIDRemote, int *peSocketStatus, uint32 *punIPRemote, uint16 *punPortRemote) override { return false; }
	bool GetListenSocketInfo(SNetListenSocket_t hListenSocket, uint32 *pnIP, uint16 *pnPort) override { return false; }
	ESNetSocketConnectionType GetSocketConnectionType(SNetSocket_t hSocket) override { return k_ESNetSocketConnectionTypeNotConnected; }
	int GetMaxPacketSize(SNetSocket_t hSocket) override { return 0; }
};

// ─── ISteamGameServerStats001 ───────────────────────────────────────────────
class SteamGameServerStatsStub : public ISteamGameServerStats {
public:
	SteamAPICall_t RequestUserStats(CSteamID steamIDUser) override { return 0; }
	bool GetUserStat(CSteamID steamIDUser, const char *pchName, int32 *pData) override { return false; }
	bool GetUserStat(CSteamID steamIDUser, const char *pchName, float *pData) override { return false; }
	bool GetUserAchievement(CSteamID steamIDUser, const char *pchName, bool *pbAchieved) override { return false; }
	bool SetUserStat(CSteamID steamIDUser, const char *pchName, int32 nData) override { return false; }
	bool SetUserStat(CSteamID steamIDUser, const char *pchName, float fData) override { return false; }
	bool UpdateUserAvgRateStat(CSteamID steamIDUser, const char *pchName, float flCountThisSession, double dSessionLength) override { return false; }
	bool SetUserAchievement(CSteamID steamIDUser, const char *pchName) override { return false; }
	bool ClearUserAchievement(CSteamID steamIDUser, const char *pchName) override { return false; }
	SteamAPICall_t StoreUserStats(CSteamID steamIDUser) override { return 0; }
};

// ─── ISteamApps005 (as vendored) ────────────────────────────────────────────
class SteamAppsStub : public ISteamApps {
public:
	bool BIsSubscribed() override { return true; }
	bool BIsLowViolence() override { return false; }
	bool BIsCybercafe() override { return false; }
	bool BIsVACBanned() override { return false; }
	const char *GetCurrentGameLanguage() override { return "english"; }
	const char *GetAvailableGameLanguages() override { return "english"; }
	bool BIsSubscribedApp(AppId_t appID) override { return true; }
	bool BIsDlcInstalled(AppId_t appID) override { return false; }
	uint32 GetEarliestPurchaseUnixTime(AppId_t nAppID) override { return 0; }
	bool BIsSubscribedFromFreeWeekend() override { return false; }
	int GetDLCCount() override { return 0; }
	bool BGetDLCDataByIndex(int iDLC, AppId_t *pAppID, bool *pbAvailable, char *pchName, int cchNameBufferSize) override { return false; }
	void InstallDLC(AppId_t nAppID) override {}
	void UninstallDLC(AppId_t nAppID) override {}
	void RequestAppProofOfPurchaseKey(AppId_t nAppID) override {}
	bool GetCurrentBetaName(char *pchName, int cchNameBufferSize) override { return false; }
	bool MarkContentCorrupt(bool bMissingFilesOnly) override { return false; }
	uint32 GetInstalledDepots(DepotId_t *pvecDepots, uint32 cMaxDepots) override { return 0; }
	uint32 GetAppInstallDir(AppId_t appID, char *pchFolder, uint32 cchFolderBufferSize) override { return 0; }
};

// ─── ISteamHTTP002 (as vendored) ────────────────────────────────────────────
class SteamHTTPStub : public ISteamHTTP {
public:
	HTTPRequestHandle CreateHTTPRequest(EHTTPMethod eHTTPRequestMethod, const char *pchAbsoluteURL) override { return 0; }
	bool SetHTTPRequestContextValue(HTTPRequestHandle hRequest, uint64 ulContextValue) override { return false; }
	bool SetHTTPRequestNetworkActivityTimeout(HTTPRequestHandle hRequest, uint32 unTimeoutSeconds) override { return false; }
	bool SetHTTPRequestHeaderValue(HTTPRequestHandle hRequest, const char *pchHeaderName, const char *pchHeaderValue) override { return false; }
	bool SetHTTPRequestGetOrPostParameter(HTTPRequestHandle hRequest, const char *pchParamName, const char *pchParamValue) override { return false; }
	bool SendHTTPRequest(HTTPRequestHandle hRequest, SteamAPICall_t *pCallHandle) override { return false; }
	bool SendHTTPRequestAndStreamResponse(HTTPRequestHandle hRequest, SteamAPICall_t *pCallHandle) override { return false; }
	bool DeferHTTPRequest(HTTPRequestHandle hRequest) override { return false; }
	bool PrioritizeHTTPRequest(HTTPRequestHandle hRequest) override { return false; }
	bool GetHTTPResponseHeaderSize(HTTPRequestHandle hRequest, const char *pchHeaderName, uint32 *unResponseHeaderSize) override { return false; }
	bool GetHTTPResponseHeaderValue(HTTPRequestHandle hRequest, const char *pchHeaderName, uint8 *pHeaderValueBuffer, uint32 unBufferSize) override { return false; }
	bool GetHTTPResponseBodySize(HTTPRequestHandle hRequest, uint32 *unBodySize) override { return false; }
	bool GetHTTPResponseBodyData(HTTPRequestHandle hRequest, uint8 *pBodyDataBuffer, uint32 unBufferSize) override { return false; }
	bool GetHTTPStreamingResponseBodyData(HTTPRequestHandle hRequest, uint32 cOffset, uint8 *pBodyDataBuffer, uint32 unBufferSize) override { return false; }
	bool ReleaseHTTPRequest(HTTPRequestHandle hRequest) override { return false; }
	bool GetHTTPDownloadProgressPct(HTTPRequestHandle hRequest, float *pflPercentOut) override { return false; }
	bool SetHTTPRequestRawPostBody(HTTPRequestHandle hRequest, const char *pchContentType, uint8 *pubBody, uint32 unBodyLen) override { return false; }
};

// ─── ISteamUser016 (as vendored) — client-side path ────────────────────────
class SteamUserStub : public ISteamUser {
public:
	HSteamUser GetHSteamUser() override { return kStubUser; }
	bool BLoggedOn() override { return true; }
	CSteamID GetSteamID() override { return CSteamID(); }
	int InitiateGameConnection(void *pAuthBlob, int cbMaxAuthBlob, CSteamID steamIDGameServer, uint32 unIPServer, uint16 usPortServer, bool bSecure) override { return 0; }
	void TerminateGameConnection(uint32 unIPServer, uint16 usPortServer) override {}
	void TrackAppUsageEvent(CGameID gameID, int eAppUsageEvent, const char *pchExtraInfo) override {}
	bool GetUserDataFolder(char *pchBuffer, int cubBuffer) override { return false; }
	void StartVoiceRecording() override {}
	void StopVoiceRecording() override {}
	EVoiceResult GetAvailableVoice(uint32 *pcbCompressed, uint32 *pcbUncompressed, uint32 nUncompressedVoiceDesiredSampleRate) override { return k_EVoiceResultNotInitialized; }
	EVoiceResult GetVoice(bool bWantCompressed, void *pDestBuffer, uint32 cbDestBufferSize, uint32 *nBytesWritten, bool bWantUncompressed, void *pUncompressedDestBuffer, uint32 cbUncompressedDestBufferSize, uint32 *nUncompressBytesWritten, uint32 nUncompressedVoiceDesiredSampleRate) override { return k_EVoiceResultNotInitialized; }
	EVoiceResult DecompressVoice(const void *pCompressed, uint32 cbCompressed, void *pDestBuffer, uint32 cbDestBufferSize, uint32 *nBytesWritten, uint32 nDesiredSampleRate) override { return k_EVoiceResultNotInitialized; }
	uint32 GetVoiceOptimalSampleRate() override { return 0; }
	HAuthTicket GetAuthSessionTicket(void *pTicket, int cbMaxTicket, uint32 *pcbTicket) override { if (pcbTicket) *pcbTicket = 0; return 0; }
	EBeginAuthSessionResult BeginAuthSession(const void *pAuthTicket, int cbAuthTicket, CSteamID steamID) override { return k_EBeginAuthSessionResultInvalidTicket; }
	void EndAuthSession(CSteamID steamID) override {}
	void CancelAuthTicket(HAuthTicket hAuthTicket) override {}
	EUserHasLicenseForAppResult UserHasLicenseForApp(CSteamID steamID, AppId_t appID) override { return k_EUserHasLicenseResultNoAuth; }
	bool BIsBehindNAT() override { return false; }
	void AdvertiseGame(CSteamID steamIDGameServer, uint32 unIPServer, uint16 usPortServer) override {}
	SteamAPICall_t RequestEncryptedAppTicket(void *pDataToInclude, int cbDataToInclude) override { return 0; }
	bool GetEncryptedAppTicket(void *pTicket, int cbMaxTicket, uint32 *pcbTicket) override { return false; }
};

SteamClientStub g_client;
SteamGameServerStub g_gs;
SteamUtilsStub g_utils;
SteamNetworkingStub g_net;
SteamGameServerStatsStub g_gstats;
SteamAppsStub g_apps;
SteamHTTPStub g_http;
SteamUserStub g_user;

ISteamUser *SteamClientStub::GetISteamUser(HSteamUser, HSteamPipe, const char *) { return &g_user; }
ISteamGameServer *SteamClientStub::GetISteamGameServer(HSteamUser, HSteamPipe, const char *) { return &g_gs; }
ISteamUtils *SteamClientStub::GetISteamUtils(HSteamPipe, const char *) { return &g_utils; }
ISteamGameServerStats *SteamClientStub::GetISteamGameServerStats(HSteamUser, HSteamPipe, const char *) { return &g_gstats; }
ISteamApps *SteamClientStub::GetISteamApps(HSteamUser, HSteamPipe, const char *) { return &g_apps; }
ISteamNetworking *SteamClientStub::GetISteamNetworking(HSteamUser, HSteamPipe, const char *) { return &g_net; }
ISteamHTTP *SteamClientStub::GetISteamHTTP(HSteamUser, HSteamPipe, const char *) { return &g_http; }

} // namespace

extern "C" {

__attribute__((visibility("default")))
void *CreateInterface(const char *pName, int *pReturnCode) {
	if (pReturnCode) *pReturnCode = 0;
	if (!strncmp(pName, "SteamClient0", 12))
		return &g_client;
	if (pReturnCode) *pReturnCode = 1;
	return nullptr;
}

// Callback-poll exports the shim resolves (must exist — BGetCallback /
// FreeLastCallback / GetAPICallResult are required for it to finish loading).
// BGetCallback always reports "no callback pending", which keeps the shim's
// pump idle: exactly what an offline stub wants.
__attribute__((visibility("default"))) bool Steam_BGetCallback(HSteamPipe hSteamPipe, struct CallbackMsg_t *pCallbackMsg) { return false; }
__attribute__((visibility("default"))) bool Steam_FreeLastCallback(HSteamPipe hSteamPipe) { return true; }
__attribute__((visibility("default"))) bool Steam_GetAPICallResult(HSteamPipe hSteamPipe, SteamAPICall_t hSteamAPICall, void *pCallback, int cubCallback, int iCallbackExpected, bool *pbFailed) { return false; }
__attribute__((visibility("default"))) void Steam_RunCallbacks(HSteamPipe hSteamPipe, bool bGameServerCallbacks) {}
__attribute__((visibility("default"))) void Steam_Shutdown() {}
__attribute__((visibility("default"))) void SteamAPI_RegisterCallback(class CCallbackBase *pCallback, int iCallback) {}
__attribute__((visibility("default"))) void SteamAPI_UnregisterCallback(class CCallbackBase *pCallback) {}
__attribute__((visibility("default"))) void Breakpad_SteamSetAppID(uint32 unAppID) {}
__attribute__((visibility("default"))) void Breakpad_SteamWriteMiniDumpUsingExceptionInfoWithBuildId(unsigned int dwProcessId, void *ExceptionInfo, int nBuildId) {}
__attribute__((visibility("default"))) void Breakpad_SteamWriteMiniDumpSetComment(const char *pchComment) {}

} // extern "C"
