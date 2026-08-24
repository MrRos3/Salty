local SALTY_URL = "https://raw.githubusercontent.com/MrRos3/Salty/main/Salty.luau"
getgenv().SALTY_LATEST_URL = SALTY_URL
return loadstring(game:HttpGet(SALTY_URL))()
