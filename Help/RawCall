--!optimize 2
--!strict 

--[[
  (public module on roblox forums called "RawLib")
  
   Copyright 2025 Ivashenko Arsenij

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]]

--this function returns the metamethod and also tries to predict if it was patched
local function returnFunc()
	local returnV = debug.info(2,"f")

	if returnV == error then
		return nil
	end

	return returnV
end

--test functions
local function index(table:any,index:string) : any return table[index] end
local function newIndex(table:any,index:string,value:any) : () table[index] = value end

local function mul(table:any,value:number) : any return table*value end
local function add(table:any,value:number) : any return table+value end
local function sub(table:any,value:number) : any return table-value end
local function div(table:any,value:number) : any return table/value end

type RawLib = {
	instance_index:(table:Instance,index:keyof<Instance>|string) -> any;
	instance_newindex:(table:Instance,index:keyof<Instance>|string,value:any) -> ();

	cframe_index:(table:CFrame,index:keyof<CFrame>) -> any;
	cframe_mul:(table:CFrame,value:CFrame|Vector3) -> CFrame|Vector3;
	cframe_add:(table:CFrame,value:Vector3) -> CFrame;
	cframe_sub:(table:CFrame,value:Vector3) -> CFrame;

	vector2_index:(table:Vector2,index:keyof<Vector2>) -> any;
	vector2_add:(table:Vector2,value:Vector2) -> Vector2;
	vector2_sub:(table:Vector2,value:Vector2) -> Vector2;
	vector2_mul:(table:Vector2,value:Vector2|number) -> Vector2;
	vector2_div:(table:Vector2,value:Vector2|number) -> Vector2;

	udim_index:(table:UDim,index:keyof<UDim>) -> any;
	udim_add:(table:UDim,value:UDim) -> UDim;
	udim_sub:(table:UDim,value:UDim) -> UDim;

	udim2_index:(table:UDim2,index:keyof<UDim2>) -> any;
	udim2_add:(table:UDim2,value:UDim2) -> UDim2;
	udim2_sub:(table:UDim2,value:UDim2) -> UDim2;

	raycastparams_index:(table:RaycastParams,index:keyof<RaycastParams>) -> any;
	raycastparams_newIndex:(table:RaycastParams,index:keyof<RaycastParams>,value:any) -> ();

	rect_index:(table:Rect,index:keyof<Rect>) -> any;
	color3_index:(table:Color3,keyof<Color3>) -> any;
	brickcolor_index:(table:BrickColor,keyof<BrickColor>) -> any;
}

local cf_identity=CFrame.identity

--There is a better method to organize all of them... Too bad!
local RawLib:RawLib = {
	instance_index = select(2,xpcall(index,returnFunc,game,"")), -- or warn("Instance index raw call is not available") and index::any;
	instance_newindex = select(2,xpcall(newIndex,returnFunc,game,"",nil)) or warn("Instance newIndex raw call is not available") and newIndex::any;

	cframe_index = select(2,xpcall(index,returnFunc,cf_identity,"")), --or warn("CFrame index raw call is not available") and index::any;
	cframe_add = select(2,xpcall(add,returnFunc,CFrame.identity,nil)) or warn("CFrame add raw call is not available") and add::any;
	cframe_sub = select(2,xpcall(sub,returnFunc,CFrame.identity,nil)) or warn("CFrame sub raw call is not available") and sub::any;
	cframe_mul = select(2,xpcall(mul,returnFunc,CFrame.identity,nil)) or warn("CFrame mul raw call is not available") and mul::any;

	vector2_index = select(2,xpcall(index,returnFunc,Vector2.zero,"")) or warn("Vector2 index raw call is not available") and index::any;
	vector2_add = select(2,xpcall(add,returnFunc,Vector2.zero,nil)) or warn("Vector2 add raw call is not available") and add::any;
	vector2_div = select(2,xpcall(div,returnFunc,Vector2.zero,nil)) or warn("Vector2 div raw call is not available") and div::any;
	vector2_mul = select(2,xpcall(mul,returnFunc,Vector2.zero,nil)) or warn("Vector2 mul raw call is not available") and mul::any;
	vector2_sub = select(2,xpcall(sub,returnFunc,Vector2.zero,nil)) or warn("Vector2 sub raw call is not available") and sub::any;

	udim_index = select(2,xpcall(index,returnFunc,UDim.new(),"")) or warn("UDim index raw call is not available") and index::any;
	udim_sub = select(2,xpcall(sub,returnFunc,UDim.new(),"")) or warn("UDim sub raw call is not available") and sub::any;
	udim_add = select(2,xpcall(add,returnFunc,UDim.new(),"")) or warn("UDim add raw call is not available") and add::any;

	udim2_index = select(2,xpcall(index,returnFunc,UDim2.new(),"")) or warn("UDim2 index raw call is not available") and index::any;
	udim2_sub = select(2,xpcall(sub,returnFunc,UDim2.new(),"")) or warn("UDim2 sub raw call is not available") and sub::any;
	udim2_add = select(2,xpcall(add,returnFunc,UDim2.new(),"")) or warn("UDim2 add raw call is not available") and add::any;

	raycastparams_index = select(2,xpcall(index,returnFunc,RaycastParams.new(),"")) or warn("RaycastParams index raw call is not available") and index::any;
	raycastparams_newIndex = select(2,xpcall(newIndex,returnFunc,RaycastParams.new(),"",nil)) or warn("RaycastParams newIndex raw call is not available") and newIndex::any;

	rect_index = select(2,xpcall(index,returnFunc,Rect.new(),"")) or warn("Rect index raw call is not available") and index::any;
	color3_index = select(2,xpcall(index,returnFunc,Color3.new(),"")) or warn("Color3 index raw call is not available") and index::any;
	brickcolor_index = select(2,xpcall(index,returnFunc,BrickColor.random(),"")) or warn("BrickColor index raw call is not available") and index::any;
}

return RawLib
