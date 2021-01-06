
#include <sourcemod>
#include <sdktools>
#include <shavit>
#include <shop>

#pragma newdecls required 

public Plugin myinfo = 
{
	name = "[shavit] Credits on MapFinish",
	author = "wyd3x",
	description = "Gives Store credits when you finish a map",
	version = "1.0",
	url = "https://forums.alliedmods.net/member.php?u=197680"
};

Handle gH_Enabled;
Handle gH_Amout;
bool gB_StoreExists;
public void OnPluginStart()
{
	
	gH_Enabled = CreateConVar("sm_giver_enabled", "1", "Store money give for map finish is enabled?", 0, true, 0.0, true, 1.0);
	gH_Amout = CreateConVar("sm_giver_amout", "20", "Amout to give on finish map", 0, true, 1.0);
	
	AutoExecConfig(true, "shavit-credits");
	
	gB_StoreExists = LibraryExists("shop");
}

public void Shavit_OnFinish(int client, int style, float time, int jumps)
{
	if(gB_StoreExists)
		if(gH_Enabled)
		{
			int credits = GetConVarInt(gH_Amout);
	
			Shop_GiveClientCredits(client, credits);
			PrintToChat(client, "\x04[Shop]\x01 You have earned %d credits for finishing this map.", credits);
		}
}
