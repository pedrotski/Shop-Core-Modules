#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <shop>

public Plugin:myinfo =
{
	name = "[Shop] Pets",
	author = "Pheonix (˙·٠●Феникс●٠·˙) & Zephyrus (Edition by MrQout & Amirsz)",
	version = "2.0",
	url = "http://www.hlmod.ru/ http://zizt.ru/"
};

enum Pet
{
	String:model[PLATFORM_MAX_PATH],
	String:run[64],
	String:idle[64],
	String:spawn[64],
	String:death[64],
	Float:fPosition[3],
	Float:fAngles[3],
}

bool g_iSpawner[MAXPLAYERS+1]={true,...};
bool g_iPets[MAXPLAYERS+1];
float g_fScale[MAXPLAYERS+1];
int g_pTicks[MAXPLAYERS+1];
char g_sPetSkin[MAXPLAYERS+1][4];
new g_unClientPet[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
new g_unSelectedPet[MAXPLAYERS+1][Pet];
new g_unLastAnimation[MAXPLAYERS+1]={-1,...};

new Handle:g_hKv;

#define CATEGORY	"pets"


public OnPluginStart()
{
	HookEvent("player_spawn", Pets_PlayerSpawn);
	HookEvent("player_death", Pets_PlayerDeath);
	
	if (Shop_IsStarted()) Shop_Started();
}

public Shop_Started()
{
	new CategoryId:category_id = Shop_RegisterCategory(CATEGORY, "Pets", "");
	
	decl String:buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(buffer, sizeof(buffer), "pets.txt");
	
	if (g_hKv != INVALID_HANDLE) CloseHandle(g_hKv);
	
	g_hKv = CreateKeyValues("Pets");
	
	if (!FileToKeyValues(g_hKv, buffer))
	{
		ThrowError("\"%s\" not parsed", buffer);
	}
	
	decl String:sName[64], String:sTitle[64], String:sDescription[64];
	KvRewind(g_hKv);

	if (KvGotoFirstSubKey(g_hKv))
	{
		do
		{
			if (KvGetSectionName(g_hKv, sName, sizeof(sName)) && Shop_StartItem(category_id, sName))
			{
				KvGetString(g_hKv, "name", sTitle, sizeof(sTitle), sName);
				KvGetString(g_hKv, "description", sDescription, sizeof(sDescription));
				
				Shop_SetInfo(sTitle, sDescription, KvGetNum(g_hKv, "price", 5000), KvGetNum(g_hKv, "sell_price", 2500), Item_Togglable, KvGetNum(g_hKv, "duration", 86400));
				Shop_SetLuckChance(KvGetNum(g_hKv, "luckchance", 0));
				Shop_SetHide(view_as<bool>(KvGetNum(g_hKv, "hide", 0)));
				Shop_SetCallbacks(_, OnEquipItem);
				
				if (KvJumpToKey(g_hKv, "Attributes", false))
				{
					Shop_KvCopySubKeysCustomInfo(g_hKv);
					KvGoBack(g_hKv);
				}
				
				Shop_EndItem();
			}
		} 
		while (KvGotoNextKey(g_hKv));
	}
	
	KvRewind(g_hKv);
}

public ShopAction:OnEquipItem(iClient, CategoryId:category_id, const String:category[], ItemId:item_id, const String:sItem[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		ResetPet(iClient);
		g_iPets[iClient]=false;
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(iClient, category_id);
	decl Float:m_fTemp[3];
	KvRewind(g_hKv);
	if (KvJumpToKey(g_hKv, sItem, false))
	{
		KvGetString(g_hKv, "model", g_unSelectedPet[iClient][model], PLATFORM_MAX_PATH);
		PrecacheModel(g_unSelectedPet[iClient][model], true);
		KvGetString(g_hKv, "idle", g_unSelectedPet[iClient][idle], 64);
		KvGetString(g_hKv, "run", g_unSelectedPet[iClient][run], 64);
		KvGetString(g_hKv, "spawn", g_unSelectedPet[iClient][spawn], 64);
		KvGetString(g_hKv, "death", g_unSelectedPet[iClient][death], 64);
		
		if (StrEqual(g_unSelectedPet[iClient][spawn], "spawn", false))
			KvGetString(g_hKv, "idle", g_unSelectedPet[iClient][spawn], 64);
		
		KvGetVector(g_hKv, "position", m_fTemp);
		g_unSelectedPet[iClient][fPosition]=m_fTemp;
		
		KvGetVector(g_hKv, "angles", m_fTemp);
		g_unSelectedPet[iClient][fAngles]=m_fTemp;
		
		g_fScale[iClient] = KvGetFloat(g_hKv, "scale", 1.0);
		KvGetString(g_hKv, "skin", g_sPetSkin[iClient], 64, "0");
		
		ResetPet(iClient);
		CreatePet(iClient);
		g_iPets[iClient]=true;
		return Shop_UseOn;
	}
	
	PrintToChat(iClient, "Failed to use \"%s\"!.", sItem);
	
	return Shop_Raw;
}

public OnClientConnected(client)
{
	g_iPets[client]=false;
}

public OnClientDisconnect(client)
{
	g_iPets[client]=false;
}

public Action:Pets_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!(2<=GetClientTeam(client)<=3) || !g_iPets[client])
		return Plugin_Continue;

	ResetPet(client);
	CreatePet(client);
	
	g_iSpawner[client] = true;

	return Plugin_Continue;
}

public Action:Pets_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetPet(client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if(!g_iPets[client] || g_unClientPet[client]==INVALID_ENT_REFERENCE || !IsPlayerAlive(client)) return;
	
	new Float:vec[3];
	decl Float:dist;
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vec);
	dist = GetVectorLength(vec);

	if(dist == 0.0)
	{
		g_pTicks[client] += 1;
		
		if (g_pTicks[client] >= 1500)
		{
			SetVariantString(g_unSelectedPet[client][run]);
			AcceptEntityInput(EntRefToEntIndex(g_unClientPet[client]), "SetAnimation");
			
			g_pTicks[client] = 0;
		}
	}
	else if(tickcount % 5 == 0)
	{
		g_pTicks[client] = 0;
		
		if (g_iSpawner[client])
		{
			SetVariantString(g_unSelectedPet[client][spawn]);
			AcceptEntityInput(EntRefToEntIndex(g_unClientPet[client]), "SetAnimation");
			
			g_iSpawner[client] = false;
			g_unLastAnimation[client]=2;
		}
		else if(g_unLastAnimation[client] != 1 && dist > 0.0)
		{
			SetVariantString(g_unSelectedPet[client][run]);
			AcceptEntityInput(EntRefToEntIndex(g_unClientPet[client]), "SetAnimation");

			g_unLastAnimation[client]=1;
		}
		else if(g_unLastAnimation[client] != 2 && dist == 0.0)
		{
			SetVariantString(g_unSelectedPet[client][idle]);
			AcceptEntityInput(EntRefToEntIndex(g_unClientPet[client]), "SetAnimation");
			
			g_unLastAnimation[client]=2;
		}
	}
}

public CreatePet(client)
{
	if(g_unClientPet[client] != INVALID_ENT_REFERENCE || !IsPlayerAlive(client)) return;


	new m_unEnt = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(m_unEnt))
	{
		new Float:m_flPosition[3];
		new Float:m_flAngles[3];
		new Float:m_flClientOrigin[3];
		new Float:m_flClientAngles[3];
		
		GetClientAbsOrigin(client, m_flClientOrigin);
		GetClientAbsAngles(client, m_flClientAngles);
	
		m_flPosition[0]=g_unSelectedPet[client][fPosition][0];
		m_flPosition[1]=g_unSelectedPet[client][fPosition][1];
		m_flPosition[2]=g_unSelectedPet[client][fPosition][2];
		m_flAngles[0]=g_unSelectedPet[client][fAngles][0];
		m_flAngles[1]=g_unSelectedPet[client][fAngles][1];
		m_flAngles[2]=g_unSelectedPet[client][fAngles][2];

		decl Float:m_fForward[3];
		decl Float:m_fRight[3];
		decl Float:m_fUp[3];
		GetAngleVectors(m_flClientAngles, m_fForward, m_fRight, m_fUp);

		m_flClientOrigin[0] += m_fRight[0]*m_flPosition[0]+m_fForward[0]*m_flPosition[1]+m_fUp[0]*m_flPosition[2];
		m_flClientOrigin[1] += m_fRight[1]*m_flPosition[0]+m_fForward[1]*m_flPosition[1]+m_fUp[1]*m_flPosition[2];
		m_flClientOrigin[2] += m_fRight[2]*m_flPosition[0]+m_fForward[2]*m_flPosition[1]+m_fUp[2]*m_flPosition[2];
		m_flAngles[1] += m_flClientAngles[1];

		DispatchKeyValue(m_unEnt, "model", g_unSelectedPet[client][model]);
		DispatchKeyValue(m_unEnt, "spawnflags", "256");
		DispatchKeyValue(m_unEnt, "solid", "0");
		DispatchKeyValue(m_unEnt, "skin", g_sPetSkin[client]);
		SetEntPropEnt(m_unEnt, Prop_Send, "m_hOwnerEntity", client);
		SetEntPropFloat(m_unEnt, Prop_Send, "m_flModelScale", g_fScale[client]);
		
		DispatchSpawn(m_unEnt);	
		AcceptEntityInput(m_unEnt, "TurnOn", m_unEnt, m_unEnt, 0);
		
		// Teleport the pet to the right fPosition and attach it
		TeleportEntity(m_unEnt, m_flClientOrigin, m_flAngles, NULL_VECTOR); 
		
		SetVariantString("!activator");
		AcceptEntityInput(m_unEnt, "SetParent", client, m_unEnt, 0);
		
		SetVariantString("letthehungergamesbegin");
		AcceptEntityInput(m_unEnt, "SetParentAttachmentMaintainOffset", m_unEnt, m_unEnt, 0);
	  
		g_unClientPet[client] = EntIndexToEntRef(m_unEnt);
		g_unLastAnimation[client] = -1;
	}
}

public ResetPet(client)
{
	if(g_unClientPet[client] == INVALID_ENT_REFERENCE)
		return;

	new m_unEnt = EntRefToEntIndex(g_unClientPet[client]);
	g_unClientPet[client] = INVALID_ENT_REFERENCE;
	if(m_unEnt == INVALID_ENT_REFERENCE)
		return;

	AcceptEntityInput(m_unEnt, "Kill");
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}