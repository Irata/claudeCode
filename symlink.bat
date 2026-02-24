SET /p folder="What is the folder name for your www installation?"

REM mklink /H e:\www\%folder%\administrator\language\en-GB\com_inventory.ini e:\repositories\LL_inventory2\language\en-GB\com_inventory.ini
REM mklink /H e:\www\%folder%\administrator\language\en-GB\com_inventory.sys.ini e:\repositories\LL_inventory2\language\en-GB\com_inventory.sys.ini
REM mklink /H e:\www\%folder%\language\en-GB\com_inventory.ini e:\repositories\LL_inventory2\language\en-GB\com_inventory.ini
mklink /J e:\www\%folder%\administrator\components\com_inventory e:\repositories\LL_inventory2\admin\com_inventory
mklink /J e:\www\%folder%\components\com_inventory e:\repositories\LL_inventory2\site\com_inventory
mklink /J e:\www\%folder%\api\components\com_inventory e:\repositories\LL_inventory2\api\com_inventory
mklink /J e:\www\%folder%\media\com_inventory e:\repositories\LL_inventory2\media\com_inventory
mklink /J e:\www\%folder%\plugins\webservices\inventory e:\repositories\LL_inventory2\plugins\webservices\inventory
mklink /J e:\www\%folder%\plugins\user\inventory e:\repositories\LL_inventory2\plugins\user\inventory
mklink /J e:\www\%folder%\plugins\console\inventoryll e:\repositories\LL_inventory2\plugins\console\inventoryll
mklink /J e:\www\%folder%\plugins\inventory\ e:\repositories\LL_inventory2\plugins\inventory

pause