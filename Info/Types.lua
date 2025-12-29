export type loaded={ --loaded dependencies table
	Camera:{
		--e.g. for typing loaded depdency fns
		--dont have any, so this is empty. scalable to that, however
		--CameraDoSomething:(a1:boolean)->boolean,
	},
	FSMs:{

	},
}
export type char=Model&{
	Root:Part&{
		LegBottom:Attachment,
		LegTop:Attachment,
	},
}
return {}
