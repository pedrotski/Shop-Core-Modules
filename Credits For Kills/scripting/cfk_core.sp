#include <sourcemod>
#include <shop>
#include <cfk>

#include <csgo_colors>

#pragma tabsize 0

#define Head 0
#define Wep 1
#define Death 2
#define KKnife 3

Handle cfk_wep;
Handle cfk_head;

int chat = 0;

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max) 
{
	cfk_wep = CreateGlobalForward("CFK_OnWepGive", ET_Hook, Param_Cell, Param_CellByRef);
	cfk_head = CreateGlobalForward("CFK_OnHeadGive", ET_Hook, Param_Cell, Param_CellByRef);      

    RegPluginLibrary("cfk");
    return APLRes_Success;    
}

Action CFK_OnHeadGive(int iClient, int& count)
{
	Action Result = Plugin_Continue;
	Call_StartForward(cfk_head);
	Call_PushCell(iClient);
	Call_PushCellRef(count);
	Call_Finish(Result);
	return Result;
}

Action CFK_OnWepGive(int iClient, int& count)
{
	Action Result = Plugin_Continue;
	Call_StartForward(cfk_wep);
	Call_PushCell(iClient);
	Call_PushCellRef(count);
	Call_Finish(Result);
	return Result;
}

void CFK_GiveCredits(int iClient, int count, int type, int id)
{
    KeyValues kv = new KeyValues("CFK");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/cfk.cfg");    
    if(kv.ImportFromFile(path))
    {
        kv.Rewind();
        chat = kv.GetNum("Chat");    
        if(type == 2)
        {
            if(kv.GetNum("Death") > 0 && Shop_GetClientCredits(iClient) - kv.GetNum("Death") >= 0)
            {
                Shop_TakeClientCredits(iClient, kv.GetNum("Death"));
                if(chat == 1)
                {
                    CGOPrintToChat(iClient, "%t", "death", kv.GetNum("Death"));
                }
            }
        }
        if(type == 0)
        {
            if(kv.GetNum("HeadShots") > 0)
            {
                count = kv.GetNum("HeadShots"); 
                switch(CFK_OnHeadGive(iClient, count))
                {
                    case Plugin_Continue:
                    {
                        Shop_GiveClientCredits(iClient, kv.GetNum("HeadShots"));
                    }
                    case Plugin_Changed:
                    {
                        Shop_GiveClientCredits(iClient, count);                       
                    }
                }
                if(chat == 1)
                {
                    CGOPrintToChat(iClient, "%t", "headshot", count);
                }                
            }
        }
        if(type == 1)
        {
            int def = count;            
            if(count > 0)
            {
                char buffer[164];

                if(id > 0){
                    kv.Rewind();
                    IntToString(id, buffer, 25);
                    if(kv.JumpToKey("Weapons")){
                        if(kv.JumpToKey(buffer)){
                            switch(CFK_OnWepGive(iClient, count))
                            {
                                case Plugin_Continue:
                                {
                                    Shop_GiveClientCredits(iClient, def);
                                    if(chat == 1)
                                    {
                                        kv.GetString("name", buffer, 164);
                                        CGOPrintToChat(iClient, "%t", "weapon_credits", buffer, def);
                                    }
                                }
                                case Plugin_Changed:
                                {
                                    Shop_GiveClientCredits(iClient, count);                       
                                    if(chat == 1)
                                    {
                                        kv.GetString("name", buffer, 164);
                                        CGOPrintToChat(iClient, "%t", "weapon_credits", buffer, count);
                                    }                    
                                }
                            } 
                        }
                    } 
                }else if(id == -1)
                {
                    switch(CFK_OnWepGive(iClient, count))
                    {
                        case Plugin_Continue:
                        {
                            Shop_GiveClientCredits(iClient, def);
                            if(chat == 1)
                            {
                                CGOPrintToChat(iClient, "%t", "knife", def);
                            }
                        }
                        case Plugin_Changed:
                        {
                            Shop_GiveClientCredits(iClient, count);                       
                            if(chat == 1)
                            {
                               CGOPrintToChat(iClient, "%t", "knife", count);
                            }                    
                        }
                    }                     
                }
            }
        }
    }else{
        PrintToServer("cfk config is missing")
    }
    delete kv;
}

bool IsValidClient(int iClient)
{
    if(iClient > 0 &&  iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient))
    {
        return true;
    }
    return false;
}

public void OnPluginStart()
{
    HookEvent("player_death", CallBacl_D, EventHookMode_Post);
    LoadTranslations("cfk_csgo.txt");
}

int GetPlayerInGameCount()
{
    int n = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i))
        {
            ++n;
        }
    }
    return n;
}
int GetConfigMin()
{
    KeyValues kv = new KeyValues("CFK");
    char path[PLATFORM_MAX_PATH+1];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/cfk.cfg");    
    if(kv.ImportFromFile(path))
    {
        int n = kv.GetNum("MinCount", 3);
        delete kv;                
        return n;   
    }
    delete kv;
    
    return -1;
}


public Action CallBacl_D(Event event, const char[] name, bool dontBroadcast)
{
    if(GetConfigMin() != -1 && GetPlayerInGameCount() >= GetConfigMin()){
        int victim = GetClientOfUserId(GetEventInt(event, "userid"));
        int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
        if(IsValidClient(victim))
        {
            CFK_GiveCredits(victim, 0, 2, 0);
        }
        if(IsValidClient(attacker))
        {
            if(GetEventBool(event, "headshot"))
            {
                CFK_GiveCredits(attacker, 0, 0, 0);            
            }

            char weapon[75],
                buffer[75];
            GetEventString(event, "weapon", weapon, 75);
            KeyValues kv = new KeyValues("CFK");
            char path[PLATFORM_MAX_PATH+1];
            BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/cfk.cfg");    
            if(kv.ImportFromFile(path))
            {
                kv.Rewind();
                if(StrContains(weapon, "knife", false) != -1 || (StrContains(weapon, "bayonet", false) != -1))
                {
                    CFK_GiveCredits(attacker, kv.GetNum("KKnife"), 1, -1);
                }
                
                if(kv.JumpToKey("Weapons"))
                {
                    if(kv.GotoFirstSubKey())
                    {
                        do
                        {
                            kv.GetString("wep", buffer, 75);
                            if(StrEqual(buffer, weapon))
                            {
                                kv.GetSectionName(buffer, 25);
                                CFK_GiveCredits(attacker, kv.GetNum("count"), 1, StringToInt(buffer));   
                                break;
                            }
                        }while (kv.GotoNextKey());	
                    }  
                }                                      
            }
            delete kv;
        }   
    }
}