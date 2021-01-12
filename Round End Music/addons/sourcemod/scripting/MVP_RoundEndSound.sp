/*
* [MVP] Round End Sound
* by: DENFER © 2020
*
* https://github.com/KWDENFER/-MVP-Round-End-Sound
* https://vk.com/denferez
* https://steamcommunity.com/id/denferez
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the GNU General Public License, version 3.0, as published by the
* Free Software Foundation.
* 
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
* details.
*
* You should have received a copy of the GNU General Public License along with
* this program. If not, see <http://www.gnu.org/licenses/>.
*/

// Main Includes 
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

// Сustom Includes
#include <colorvariables>
#include <autoexecconfig>

// My Includes Part 1
#include <denfer>

// Defines
#define MVPSOUND_VERSION "1.2"
#define AUTHOR 	"DENFER"

// Pragma 
#pragma newdecls required
#pragma semicolon 1
#pragma tabsize 0 

// Strings
char g_sPrefix[32];
char g_sDonateLink[MAXPLAYERS+1][MAX_NAME_LENGTH];
char g_sPathBuffer[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sKitBuffer[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_szPathMusicKeyValues[PLATFORM_MAX_PATH];
char g_szPathPlayersKeyValues[PLATFORM_MAX_PATH];
char g_szPathSettingsKeyValues[PLATFORM_MAX_PATH];
char g_szPathShopKeyValues[PLATFORM_MAX_PATH];
char g_sAudioPlayer[PLATFORM_MAX_PATH];
char g_sPlaylist[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sCheckVolume[PLATFORM_MAX_PATH];

// Handles
Handle g_hTimer;

StringMap g_hMusicTrie;

// ConVars
ConVar gc_sPrefix;
ConVar gc_bShop;
ConVar gc_sDonateLink;
ConVar gc_bOffSoundMVP;
ConVar gc_bCustomToggleMVP;
ConVar gc_bViewYourKits;
ConVar gc_bViewOtherKits;
ConVar gc_bPluginMessage;
ConVar gc_bVolume;
ConVar gc_sCheckVolume;

// Floats
float g_flVolume[MAXPLAYERS+1];

// Integers
int g_iCompositions[MAXPLAYERS+1];
int g_iShopBuffer[MAXPLAYERS+1];
int g_iTarget[MAXPLAYERS+1];
int g_iKits[MAXPLAYERS+1];
int g_iMVPBuffer;
int g_iVolume[MAXPLAYERS+1];

int g_iSounds;
int g_iEntitySound[MAX_EDICTS];

// Booleans
bool g_bMVPMusic[MAXPLAYERS+1];
bool g_bDisableMVPMusic[MAXPLAYERS+1][MAXPLAYERS+1];
bool g_bBuy[MAXPLAYERS+1];	
bool g_bMenuPosition[MAXPLAYERS+1];
bool g_bOther[MAXPLAYERS+1];

// My Includes Part 2
#include <mvpsound>

// Modules
#include "DENFER/MVP_RoundEndSound/functions.sp"
#include "DENFER/MVP_RoundEndSound/menus.sp"
#include "DENFER/MVP_RoundEndSound/natives.sp"

// Information
public Plugin myinfo = {
	name = "[MVP] Round End Sound",
	author = "DENFER (for all questions - https://vk.com/denferez)",
	description = "Plays custom music when the player becomes the MVP of the round",
	version = MVPSOUND_VERSION,
};

/* *******************************************************
 *
 *   					STARTUP  
 *
 * ******************************************************** */
 
 
 public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("MVP_GetClientMusicKits", Native_MVP_GetClientMusicKits);
	CreateNative("MVP_GetClientCompositions", Native_MVP_GetClientCompositions);
	CreateNative("MVP_IsClientListen", Native_MVP_IsClientListen);
	CreateNative("MVP_SetClientPlayMusic", Native_MVP_SetClientPlayMusic);
	
	RegPluginLibrary("mvpsound");
	
	return APLRes_Success;
}
 
 public void OnPluginStart()
 {
	// Translation 
	LoadTranslations("MVP_RoundEndSound.phrases");
	
	// AutoExecConfig
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("MVP_RoundEndSound", AUTHOR);
	
	// Console Commands
	RegConsoleCmd("sm_music", Menu_Music, "Calls the main menu of the plugin");
	
	gc_sPrefix = AutoExecConfig_CreateConVar("sm_mvps_prefix", "[{green}SM{default}]", "Префикс перед сообщениями плагина?");
	gc_bPluginMessage = AutoExecConfig_CreateConVar("sm_mvps_plugin_message", "1", "Включить сообщения плагина? (0 - выкл, 1 - вкл)", 0, true, 0.0, true, 1.0);
	gc_bOffSoundMVP = AutoExecConfig_CreateConVar("sm_mvps_off_sound", "1", "Разрешить игрокам запрещать музыку MVP, тогда они не будут совсем слышать любую музыку? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
	gc_bCustomToggleMVP = AutoExecConfig_CreateConVar("sm_mvps_toggle_sound", "1", "Разрешить игрокам самим выбирать игроков, у которых бы они не хотели бы слышать музыку MVP? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
	gc_bViewYourKits = AutoExecConfig_CreateConVar("sm_mvps_view_kits", "1", "Разрешить игрокам просматривать свои музыкальные альбомы с музыкой в них? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
	gc_bViewOtherKits = AutoExecConfig_CreateConVar("sm_mvps_view_other_kits", "1", "Разрешить игрокам просматривать музыкальные наборы c музыкой в них других игроков? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
	gc_bShop = AutoExecConfig_CreateConVar("sm_mvps_shop", "1", "Разрешить специальном магазин от плагина, в котором вы можете информировать игроков о стоимости и прочей информации товара? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
	gc_bVolume = AutoExecConfig_CreateConVar("sm_mvps_volume", "1", "Разрешить игрокам настраивать самим громкость воспроизведения музыки? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
	gc_sCheckVolume = AutoExecConfig_CreateConVar("sm_mvps_check_volume", "DENFER/MVP_RoundEndSound/test.mp3", "Путь к файлу для проверки звука, используйте его только при sm_mvps_volume = 1!");
	gc_sDonateLink = AutoExecConfig_CreateConVar("sm_mvps_donate_link", "https://vk.com/denferez", "Ссылка на магазин или пользователя, который предоставляет платные услуги (если вы не указали ссылку в спеицальном конфиге settings.cfg, то будет выводиться данная ссылка при нажатие 'Купить')");
	
	HookEvent("round_mvp", Event_MVP);	
	HookEvent("round_start", Event_RoundStart);
		
	// AutoExecConfig
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
 }
 
 /* *******************************************************
 *
 *   					FORWARDS  
 *
 * ******************************************************** */
 
 public void OnConfigsExecuted()
 {
	KeyValues hPlayersKeyValues = new KeyValues("Players");
	InitKeyValuePlayersStruct(hPlayersKeyValues, "configs/DENFER/MVP_RoundEndSound/players.cfg");
	delete hPlayersKeyValues;
	
	KeyValues hSettingsKeyValues = new KeyValues("Settings");
	InitKeyValueSettingsStruct(hSettingsKeyValues, "configs/DENFER/MVP_RoundEndSound/settings.cfg");
	delete hSettingsKeyValues;
	
	if(gc_bShop.BoolValue)
	{
		KeyValues hShopKeyValues = new KeyValues("Shop");
		InitKeyValueShopStruct(hShopKeyValues, "configs/DENFER/MVP_RoundEndSound/shop.cfg");
		delete hShopKeyValues;
	}
	
	gc_sPrefix.GetString(g_sPrefix, sizeof(g_sPrefix));
	gc_sCheckVolume.GetString(g_sCheckVolume, sizeof(g_sCheckVolume));
 }
 
 public void OnMapStart()
 {
	KeyValues hMusicKeyValues = new KeyValues("Music");
	InitKeyValueMusicStruct(hMusicKeyValues, "configs/DENFER/MVP_RoundEndSound/music.cfg");
	delete hMusicKeyValues;
	
	PrecacheAndDownloadSoundFile("DENFER/MVP_RoundEndSound/test.mp3");
	
	// init default values
	for(int i = 1; i <= MaxClients; ++i)
	{
		g_iVolume[i] = 100;
		g_flVolume[i] = 1.0;
		g_bMVPMusic[i] = true;
	}
 }
 
 public void OnClientDisconnect(int client)
 {
	SetsDefaultClientOptions(client);
 }
 
 /* *******************************************************
 *
 *   					HOOKS  
 *
 * ******************************************************** */
 
 public void Event_MVP(Event event, const char[] name, bool dontBroadcast)
 {
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	OffOtherSounds();
	
	if(g_hTimer != null)
	{
		KillTimer(g_hTimer);
		g_hTimer = null;
	}
	
	g_hTimer = CreateTimer(0.25, Timer_PlayMusic, GetClientUserId(client));
 }
 
 public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
 {
	SaveSoundsOnMap();
 }	
 
/* *******************************************************
 *
 *   					TIMERS  
 *
 * ******************************************************** */
 
 public Action Timer_PlayMusic(Handle timer, int userid)
 {
	int client = GetClientOfUserId(userid);
	
	if(client)
	{
		if(IsValidClient(client) && !IsBotClient(client))
		{
			if(SetMusicMVP(client))
			{
				PlayMusic(client);
			}
		}
	}
	
	g_hTimer = null;
 }