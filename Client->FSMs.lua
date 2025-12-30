--!native
--!optimize 2
local Types=require(script.Parent.Info.Types)
type loaded=Types.loaded
type char=Types.char

local RawCall=require(script.Parent.Help.RawCall)--use raw path for autocompleteand types
local SetInstanceNewIndex=RawCall.instance_newindex -- equivalent to script.Name = foo
local GetCFrameIndex=RawCall.cframe_index
local GetInstanceIndex=RawCall.instance_index

local UIS=game:GetService('UserInputService')
local RS=game:GetService('RunService')
local PreSim=RS.PreSimulation
local req=require
local CF_new=CFrame.new
local vec_zero=vector.zero
local p=pairs
local ip=ipairs

--preload factory fns to their fsm names
local t_factories={}
for _,m in ip(script:GetChildren()) do
	if not m:IsA('ModuleScript') then continue end
	t_factories[m.Name]=req(m)
end

return function(loaded:loaded,char:char)
	--batching the conns for more perf. look in the comment at the bottom in Client for more info
	local loaded_FSMs={}
	local len_arr_Update --microop
	local len_arr_UIS_began --microop
	local len_arr_UIS_ended --microop
	local arr_Update={}
	local arr_UIS_began={}
	local arr_UIS_ended={}
	for name:string,fn in p(t_factories) do
		-- instantiating from the factory fns ref table made before
		loaded_FSMs[name]=fn(loaded,char) 
		--pass in the loaded depdendencies table for if we want to e.g. do an exposed fn from the Camera manager
		
		--// checking if we have this, if so, put it in the batched arr
		local t=loaded_FSMs[name] --avoids repeated lookups
		local Update=t.Update
		if Update then arr_Update[#arr_Update+1]=Update end
		local InputBegan=t.InputBegan
		if InputBegan then arr_UIS_began[#arr_UIS_began+1]=InputBegan end
		local InputEnded=t.InputEnded
		if InputEnded then arr_UIS_ended[#arr_UIS_ended+1]=InputEnded end
	end
	len_arr_Update=#arr_Update
	len_arr_UIS_began=#arr_UIS_began
	len_arr_UIS_ended=#arr_UIS_ended
	
	--// used numerical loops, fastest for this case
	-- ipairs has fn overhead so i didnt use ip
	
	-- further improvement is to do a first pass where u form the size of the arrays, then use table.create for each arr
	-- but it would be unnecesarily for the app
	
	--// doing the batched arrays
	RS:BindToRenderStep('Physics',Enum.RenderPriority.Camera.Value-1,function(dt:number)
		--set before camera step so cam sees and uses updated root pos from FSM physics
		for i=1,len_arr_Update do 
			arr_Update[i](dt) 
		end
	end)
	--// by batching, we avoid a extra "if gp then..." and table lookups for KeyCode and UIS type 
	--for every input began we might have
	--means better perf
	local c_input=UIS.InputBegan:Connect(function(i:InputObject,gp:boolean)
		if gp then return end
		local key=i.KeyCode
		local i_type=i.UserInputType
		for index=1,len_arr_UIS_began do 
			arr_UIS_began[index](key,i_type) 
		end
	end)
	local c_input_end=UIS.InputEnded:Connect(function(i:InputObject,gp:boolean)
		if gp then return end
		local key=i.KeyCode
		local i_type=i.UserInputType
		for index=1,len_arr_UIS_ended do 
			arr_UIS_ended[index](key,i_type) 
		end
	end)
	
	return {
    Wipe=function()

    end,
  }
end
