--!optimize 2

--[[
notes:
- In Move,slope movement is buggy. however this is enough for the purposes of showing luau programmer.
- In Move,collide and slide is buggy. 
	1. no spherecast margins yet, so its inevitably buggy rn, until they release

this is the client framework bootstrapper script in game.ReplicatedFirst. loads all factory fns into tables and calls them (starts them)

'vars'='variables'
'fns'='functions'
'perf'='performance'
]]
game.Loaded:Wait()
game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.All,false)

--// i understand that it's not necessary to cache so much for perf. it helps me read it faster
--// grouped vars together because it makes me read faster
local os_clock=os.clock
local task_wait=task.wait
local p=pairs
local ip=ipairs
local s=script
local CF_new=CFrame.new
local req=require
local worksp=workspace

--// populate state dictionary once
local t_factory_fns_managers={}
for _,m:ModuleScript in ip(s:GetChildren()) do
	if not m:IsA('ModuleScript') then continue end
	t_factory_fns_managers[m.Name]=req(m)
end

--// "settings"
local spawn_cf=CF_new(0,5,0)
local char_template=game.ReplicatedStorage.Char
local ExeOrder:{string}=req(s.Info.ExeOrder) --array
--// const
local len_exe_order_arr=#ExeOrder --easy microop

--// changing
local EndClient

--// lifetime fns
local function StartClient()
	local char=char_template:Clone()
	char:PivotTo(spawn_cf)
	char.Parent=worksp
	
	local arr_Wipe_len
	local arr_Wipe={}
	local t_loaded_managers={}
	for i=1,len_exe_order_arr do 
		local name:string=ExeOrder[i]
		--this framework uses the Factory Pattern
		--where each manager module returns a function, which returns a table of its state-cleanup fn
		--and other fns which other managers may want to access
		--below: natural depdendency injection. u must always only access the previous loaded managers
		--in any manager
		--if this contract is followed, circular deps are impossible
		t_loaded_managers[name]=t_factory_fns_managers[name](t_loaded_managers,char)
		local t_ref=t_loaded_managers[name]
		if not t_ref then warn('no t_ref returned from factory',name) end

		local Wipe=t_ref.Wipe
		if Wipe then arr_Wipe[#arr_Wipe+1]=Wipe end --// make cleanup just a very fast numerical loop
	end
	arr_Wipe_len=#arr_Wipe --easy microp after arr is populated for use in cleanup
	
	EndClient=function()
		EndClient=nil --habit
		
		--// make each manager wipe their own state before setting to nil
		for i=1,arr_Wipe_len do arr_Wipe[i]() end
		arr_Wipe=nil
		
		--// now safely set managers to nil after they wiped
		for n:string,_ in p(t_loaded_managers) do t_loaded_managers[n]=nil end
		t_loaded_managers=nil
		
		--// nil any other state
		char:Destroy()
		char=nil
	end
end

--// starting client
local a=os_clock()
StartClient()
print('client',os_clock()-a)

--[[ at scale:
- u can optionally batch UIS.InputBegan,UIS.inputended, etc, in an array if this becomes greater scale
UIS.InputBegan:Connect(fn(obj,gp)
	if gp then return end
	
	--i save two table lookups per. wheras if u repeated inputbegan, it'd access the table. 
	--for every conn which is inefficient
	local key=obj.KeyCode
	local type=obj.UserInputType
	for i=1,len_arr_InputBegan do
		arr_InputBegan[i](key,type)
	end
end)
]]

--task_wait(1.5)
--local a=os_clock()
--EndClient()
--print('end client took',os_clock()-a)
