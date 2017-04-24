﻿package dragonBones.objects
{
/**
 * @language zh_CN
 * 动画数据。
 * @version DragonBones 3.0
 */
public final class AnimationData extends TimelineData
{
	/**
	 * @language zh_CN
	 * 持续的帧数。
	 * @version DragonBones 3.0
	 */
	public var frameCount:UInt;
	/**
	 * @language zh_CN
	 * 播放次数。 [0: 无限循环播放, [1~N]: 循环播放 N 次]
	 * @version DragonBones 3.0
	 */
	public var playTimes:UInt;
	/**
	 * @language zh_CN
	 * 持续时间。 (以秒为单位)
	 * @version DragonBones 3.0
	 */
	public var duration:Float;
	/**
	 * @language zh_CN
	 * 淡入时间。 (以秒为单位)
	 * @version DragonBones 3.0
	 */
	public var fadeInTime:Float;
	/**
	 * @private
	 */
	public var cacheFrameRate:Float;
	/**
	 * @language zh_CN
	 * 数据名称。
	 * @version DragonBones 3.0
	 */
	public var name:String;
	/**
	 * @private
	 */
	public var zOrderTimeline:ZOrderTimelineData;
	/**
	 * @private
	 */
	public inline var boneTimelines:Object = {};
	/**
	 * @private
	 */
	public inline var slotTimelines:Object = {};
	/**
	 * @private
	 */
	public inline var ffdTimelines:Object = {}; // skinName ,slotName, mesh
	/**
	 * @private
	 */
	public inline var cachedFrames:Vector.<Boolean> = new Vector.<Boolean>();
	/**
	 * @private
	 */
	public inline var boneCachedFrameIndices: Object = {}; //Object<Vector.<Number>>
	/**
	 * @private
	 */
	public inline var slotCachedFrameIndices: Object = {}; //Object<Vector.<Number>>
	/**
	 * @private
	 */
	public function AnimationData()
	{
		super(this);
	}
	/**
	 * @private
	 */
	override private function _onClear():Void
	{
		super._onClear();
		
		for (var k:String in boneTimelines)
		{
			(boneTimelines[k] as BoneTimelineData).returnToPool();
			delete boneTimelines[k];
		}
		
		for (k in slotTimelines)
		{
			(slotTimelines[k] as SlotTimelineData).returnToPool();
			delete slotTimelines[k];
		}
		
		for (k in ffdTimelines) {
			for (var kA:String in ffdTimelines[k]) 
			{
				for (var kB:String in ffdTimelines[k][kA]) 
				{
					(ffdTimelines[k][kA][kB] as FFDTimelineData).returnToPool();
				}
			}
			
			delete ffdTimelines[k];
		}
		
		for (k in boneCachedFrameIndices) 
		{
			// boneCachedFrameIndices[i].length = 0;
			delete boneCachedFrameIndices[k];
		}
		
		for (k in slotCachedFrameIndices) {
			// slotCachedFrameIndices[i].length = 0;
			delete slotCachedFrameIndices[k];
		}
		
		if (zOrderTimeline) 
		{
			zOrderTimeline.returnToPool();
		}
		
		frameCount = 0;
		playTimes = 0;
		duration = 0.0;
		fadeInTime = 0.0;
		cacheFrameRate = 0.0;
		name = null;
		//boneTimelines.clear();
		//slotTimelines.clear();
		//ffdTimelines.clear();
		cachedFrames.fixed = false;
		cachedFrames.length = 0;
		//boneCachedFrameIndices.clear();
		//boneCachedFrameIndices.clear();
		zOrderTimeline = null;
	}
	/**
	 * @private
	 */
	public function cacheFrames(frameRate:Float):Void
	{
		if (cacheFrameRate > 0.0)
		{
			return;
		}
		
		cacheFrameRate = Math.max(Math.ceil(frameRate * scale), 1.0);
		inline var cacheFrameCount:UInt = Math.ceil(cacheFrameRate * duration) + 1; // uint
		cachedFrames.length = cacheFrameCount;
		cachedFrames.fixed = true;
		
		for (var k:String in boneTimelines) 
		{
			var indices:Vector.<int> = new Vector.<int>(cacheFrameCount, true)
			for (var i:UInt = 0, l:UInt = indices.length; i < l; ++ i)
			{
				indices[i] = -1;
			}
			
			boneCachedFrameIndices[k] = indices;
		}
		
		for (k in slotTimelines) 
		{
			indices = new Vector.<int>(cacheFrameCount, true)
			for (i = 0, l = indices.length; i < l; ++ i)
			{
				indices[i] = -1;
			}
			
			slotCachedFrameIndices[k] = indices;
		}
	}
	/**
	 * @private
	 */
	public function addBoneTimeline(value:BoneTimelineData):Void
	{
		if (value && value.bone && !boneTimelines[value.bone.name])
		{
			boneTimelines[value.bone.name] = value;
		}
		else
		{
			throw new ArgumentError();
		}
	}
	/**
	 * @private
	 */
	public function addSlotTimeline(value:SlotTimelineData):Void
	{
		if (value && value.slot && !slotTimelines[value.slot.name])
		{
			slotTimelines[value.slot.name] = value;
		}
		else
		{
			throw new ArgumentError();
		}
	}
	/**
	 * @private
	 */
	public function addFFDTimeline(value:FFDTimelineData):Void
	{
		if (value && value.skin && value.slot)
		{
			inline var skin:Object = ffdTimelines[value.skin.name] = ffdTimelines[value.skin.name] || {};
			inline var slot:Object = skin[value.slot.slot.name] = skin[value.slot.slot.name] || {};
			if (!slot[value.display.name])
			{
				slot[value.display.name] = value;
			}
			else
			{
				throw new ArgumentError();
			}
		}
		else
		{
			throw new ArgumentError();
		}
	}
	/**
	 * @private
	 */
	public function getBoneTimeline(name:String):BoneTimelineData
	{
		return boneTimelines[name] as BoneTimelineData;
	}
	/**
	 * @private
	 */
	public function getSlotTimeline(name:String):SlotTimelineData
	{
		return slotTimelines[name] as SlotTimelineData;
	}
	/**
	 * @private
	 */
	public function getFFDTimeline(skinName:String, slotName:String):Object
	{
		inline var skin:Object = ffdTimelines[skinName];
		if (skin)
		{
			return skin[slotName];
		}
		
		return null;
	}
	/**
	 * @private
	 */
	public function getBoneCachedFrameIndices(name: String): Vector.<int> 
	{
		return boneCachedFrameIndices[name];
	}
	/**
	 * @private
	 */
	public function getSlotCachedFrameIndices(name: String): Vector.<int> 
	{
		return slotCachedFrameIndices[name];
	}
}
}