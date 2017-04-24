﻿package dragonBones.animation;

import dragonBones.Armature;
import dragonBones.Bone;
import dragonBones.Slot;
import dragonBones.core.BaseObject;
import dragonBones.core.dragonBones_internal;
import dragonBones.objects.AnimationConfig;
import dragonBones.objects.AnimationData;
import openfl.Vector;

/**
 * @language zh_CN
 * 动画控制器，用来播放动画数据，管理动画状态。
 * @see dragonBones.objects.AnimationData
 * @see dragonBones.animation.AnimationState
 * @version DragonBones 3.0
 */
class Animation extends BaseObject
{
	private static function _sortAnimationState(a:AnimationState, b:AnimationState):Int
	{
		return a.layer > b.layer? -1: 1;
	}
	/**
	 * @language zh_CN
	 * 动画播放速度。 [(-N~0): 倒转播放, 0: 停止播放, (0~1): 慢速播放, 1: 正常播放, (1~N): 快速播放]
	 * @default 1
	 * @version DragonBones 3.0
	 */
	public var timeScale:Float;
	
	private var _isPlaying:Bool;
	private var _animationStateDirty:Bool;
	/**
	 * @private
	 */
	@:allow("dragonBones") private var _timelineStateDirty:Bool;
	/**
	 * @private
	 */
	@:allow("dragonBones") private var _cacheFrameIndex:Float;
	private inline var _animationNames:Vector<String> = new Vector<String>();
	private inline var _animations:Map<String, AnimationData> = new Map<String, AnimationData>();
	private inline var _animationStates:Vector<AnimationState> = new Vector<AnimationState>();
	private var _armature:Armature;
	private var _lastAnimationState:AnimationState;
	private var _animationConfig:AnimationConfig;
	/**
	 * @private
	 */
	public function new()
	{
		super(this);
	}
	/**
	 * @private
	 */
	override private function _onClear():Void
	{
		var l:UInt = _animationStates.length;
		for (i in 0...l)
		{
			_animationStates[i].returnToPool();
		}
		
		if (_animationConfig) 
		{
			_animationConfig.returnToPool();
		}
		
		_animations = new Map();
		
		timeScale = 1.0;
		
		_isPlaying = false;
		_animationStateDirty = false;
		_timelineStateDirty = false;
		_cacheFrameIndex = -1;
		_animationNames.length = 0;
		//_animations.clear();
		_animationStates.length = 0;
		_armature = null;
		_lastAnimationState = null;
		_animationConfig = null;
	}
	
	private function _fadeOut(animationConfig:AnimationConfig):Void
	{
		var i:UInt = 0, l:UInt = _animationStates.length;
		var animationState:AnimationState = null
		
		switch (animationConfig.fadeOutMode)
		{
			case AnimationFadeOutMode.SameLayer:
				for ( ; i < l; ++i)
				{
					animationState = _animationStates[i];
					if (animationState.layer === animationConfig.layer)
					{
						animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
					}
				}
				break;
			
			case AnimationFadeOutMode.SameGroup:
				for ( ; i < l; ++i)
				{
					animationState = _animationStates[i];
					if (animationState.group === animationConfig.group)
					{
						animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
					}
				}
				break;
			
			case AnimationFadeOutMode.SameLayerAndGroup:
				for ( ; i < l; ++i)
				{
					animationState = _animationStates[i];
					if (
						animationState.layer === animationConfig.layer &&
						animationState.group === animationConfig.group
					)
					{
						animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
					}
				}
				break;
			
			case AnimationFadeOutMode.All:
				for ( ; i < l; ++i)
				{
					animationState = _animationStates[i];
					animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
				}
				break;
			
			case AnimationFadeOutMode.None:
			default:
				break;
		}
	}
	/**
	 * @private
	 */
	public function _init(armature:Armature):Void 
	{
		if (_armature != null) 
		{
			return;
		}
		
		_armature = armature;
		_animationConfig = BaseObject.borrowObject(AnimationConfig) as AnimationConfig;
	}
	/**
	 * @private
	 */
	@:allow("dragonBones") private function _advanceTime(passedTime:Float):Void
	{
		if (!_isPlaying)
		{
			return;
		}
		
		if (passedTime < 0.0)
		{
			passedTime = -passedTime;
		}
		
		if (_armature.inheritAnimation && _armature._parent != null) // Inherit parent animation timeScale.
		{
			passedTime *= _armature._parent._armature.animation.timeScale;
		}
		
		if (timeScale !== 1.0) 
		{
			passedTime *= timeScale;
		}
		
		var animationState:AnimationState = null;
		
		inline var animationStateCount:UInt = _animationStates.length;
		if (animationStateCount === 1)
		{
			animationState = _animationStates[0];
			if (animationState._fadeState > 0 && animationState._subFadeState > 0)
			{
				animationState.returnToPool();
				_animationStates.length = 0;
				_animationStateDirty = true;
				_lastAnimationState = null;
			}
			else
			{
				inline var animationData:AnimationData = animationState.animationData;
				inline var cacheFrameRate:Float = animationData.cacheFrameRate;
				
				if (_animationStateDirty && cacheFrameRate > 0.0) // Update cachedFrameIndices.
				{
					_animationStateDirty = false;
					
					inline var bones:Vector<Bone> = _armature.getBones();
					var l:UInt = bones.length;
					for (i in 0...l)
					{
						inline var bone:Bone = bones[i];
						bone._cachedFrameIndices = animationData.getBoneCachedFrameIndices(bone.name);
					}
					
					inline var slots:Vector<Slot> = _armature.getSlots();
					l = slots.length;
					for (i in 0...l)
					{
						inline var slot:Slot = slots[i];
						slot._cachedFrameIndices = animationData.getSlotCachedFrameIndices(slot.name);
					}
				}
				
				if (_timelineStateDirty) 
				{
					animationState._updateTimelineStates();
				}
				
				animationState._advanceTime(passedTime, cacheFrameRate);
			}
		}
		else if (animationStateCount > 1)
		{
			var r:UInt = 0;
			for (i in 0...animationStateCount)
			{
				animationState = _animationStates[i];
				if (animationState._fadeState > 0 && animationState._fadeProgress <= 0)
				{
					r++;
					animationState.returnToPool();
					_animationStateDirty = true;
					
					if (_lastAnimationState == animationState)
					{
						_lastAnimationState = null;
					}
				}
				else
				{
					if (r > 0)
					{
						_animationStates[i - r] = animationState;
					}
					
					if (_timelineStateDirty) 
					{
						animationState._updateTimelineStates();
					}
					
					animationState._advanceTime(passedTime, 0.0);
				}
				
				if (i == animationStateCount - 1 && r > 0)
				{
					_animationStates.length -= r;
					
					if (!_lastAnimationState && _animationStates.length > 0) 
					{
						_lastAnimationState = _animationStates[_animationStates.length - 1];
					}
				}
			}
			
			_cacheFrameIndex = -1;
		}
		else
		{
			_cacheFrameIndex = -1;
		}
		
		_timelineStateDirty = false;
	}
	/**
	 * @language zh_CN
	 * 清除所有动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function reset():Void
	{
		var l:UInt = _animationStates.length;
		for (i in 0...l)
		{
			_animationStates[i].returnToPool();
		}
		
		_isPlaying = false;
		_animationStateDirty = false;
		_timelineStateDirty = false;
		_cacheFrameIndex = -1;
		_animationConfig.clear();
		_animationStates.length = 0;
		_lastAnimationState = null;
	}
	/**
	 * @language zh_CN
	 * 暂停播放动画。
	 * @param animationName 动画状态的名称，如果未设置，则暂停所有动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 3.0
	 */
	public function stop(animationName:String = null):Void
	{
		if (animationName != null)
		{
			inline var animationState:AnimationState = getState(animationName);
			if (animationState != null)
			{
				animationState.stop();
			}
		}
		else
		{
			_isPlaying = false;
		}
	}
	/**
	 * @language zh_CN
	 * @beta
	 * 通过动画配置来播放动画。
	 * @param animationConfig 动画配置。
	 * @returns 对应的动画状态。
	 * @see dragonBones.objects.AnimationConfig
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 5.0
	 */
	public function playConfig(animationConfig:AnimationConfig):AnimationState 
	{
		if (animationConfig == null) 
		{
			throw new ArgumentError();
			return null;
		}
		
		inline var animationName:String = animationConfig.animationName ? animationConfig.animationName : animationConfig.name;
		inline var animationData:AnimationData = _animations[animationName];
		if (animationData == null) 
		{
			trace(
				"Non-existent animation.\n",
				"DragonBones name: " + _armature.armatureData.parent.name,
				"Armature name: " + _armature.name,
				"Animation name: " + animationName
			);
			
			return null;
		}
		
		_isPlaying = true;
		
		if (animationConfig.playTimes < 0) 
		{
			animationConfig.playTimes = animationData.playTimes;
		}
		
		if (animationConfig.fadeInTime < 0.0 || animationConfig.fadeInTime !== animationConfig.fadeInTime) 
		{
			if (_lastAnimationState) 
			{
				animationConfig.fadeInTime = animationData.fadeInTime;
			}
			else 
			{
				animationConfig.fadeInTime = 0.0;
			}
		}
		
		if (animationConfig.fadeOutTime < 0.0 || animationConfig.fadeOutTime !== animationConfig.fadeOutTime) 
		{
			animationConfig.fadeOutTime = animationConfig.fadeInTime;
		}
		
		if (animationConfig.timeScale <= -100.0 || animationConfig.timeScale !== animationConfig.timeScale) //
		{
			animationConfig.timeScale = 1.0 / animationData.scale;
		}
		
		if (animationData.duration > 0.0) 
		{
			if (animationConfig.position !== animationConfig.position) 
			{
				animationConfig.position = 0.0;
			}
			else if (animationConfig.position < 0.0) 
			{
				animationConfig.position %= animationData.duration;
				animationConfig.position = animationData.duration - animationConfig.position;
			}
			else if (animationConfig.position === animationData.duration) 
			{
				animationConfig.position -= 0.001;
			}
			else if (animationConfig.position > animationData.duration) 
			{
				animationConfig.position %= animationData.duration;
			}
			
			if (animationConfig.position + animationConfig.duration > animationData.duration) 
			{
				animationConfig.duration = animationData.duration - animationConfig.position;
			}
		}
		else 
		{
			animationConfig.position = 0.0;
			animationConfig.duration = -1.0;
		}
		
		inline var isStop:Bool = animationConfig.duration === 0.0;
		if (isStop) 
		{
			animationConfig.playTimes = 1;
			animationConfig.duration = -1.0;
			animationConfig.fadeInTime = 0.0;
		}
		
		_fadeOut(animationConfig);
		
		_lastAnimationState = BaseObject.borrowObject(AnimationState) as AnimationState;
		_lastAnimationState._init(_armature, animationData, animationConfig);
		_animationStates.push(_lastAnimationState);
		_animationStateDirty = true;
		_cacheFrameIndex = -1;
		
		if (_animationStates.length > 1)
		{
			_animationStates.sort(Animation._sortAnimationState);
		}
		
		// Child armature play same name animation.
		inline var slots:Vector<Slot> = _armature.getSlots();
		var l:UInt = slots.length;
		for (i in 0...l)
		{
			inline var childArmature:Armature = slots[i].childArmature;
			if (
				childArmature != null && childArmature.inheritAnimation &&
				childArmature.animation.hasAnimation(animationName) &&
				!childArmature.animation.getState(animationName)
			) 
			{
				childArmature.animation.fadeIn(animationName); //
			}
		}
		
		if (animationConfig.fadeInTime <= 0.0) // Blend animation state, update armature.
		{
			_armature.advanceTime(0.0);
		}
		
		if (isStop) 
		{
			_lastAnimationState.stop();
		}
		
		return _lastAnimationState;
	}
	/**
	 * @language zh_CN
	 * 淡入播放动画。
	 * @param animationName 动画数据名称。
	 * @param playTimes 播放次数。 [-1: 使用动画数据默认值, 0: 无限循环播放, [1~N]: 循环播放 N 次]
	 * @param fadeInTime 淡入时间。 [-1: 使用动画数据默认值, [0~N]: 淡入时间] (以秒为单位)
	 * @param layer 混合图层，图层高会优先获取混合权重。
	 * @param group 混合组，用于动画状态编组，方便控制淡出。
	 * @param fadeOutMode 淡出模式。
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationFadeOutMode
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function fadeIn(
		animationName:String, fadeInTime:Float = -1.0, playTimes:Int = -1,
		layer:Int = 0, group:String = null, fadeOutMode:Int = AnimationFadeOutMode.SameLayerAndGroup
	):AnimationState
	{
		_animationConfig.clear();
		_animationConfig.fadeOutMode = fadeOutMode;
		_animationConfig.playTimes = playTimes;
		_animationConfig.layer = layer;
		_animationConfig.fadeInTime = fadeInTime;
		_animationConfig.animationName = animationName;
		_animationConfig.group = group;
		
		return playConfig(_animationConfig);
	}
	/**
	 * @language zh_CN
	 * 播放动画。
	 * @param animationName 动画数据名称，如果未设置，则播放默认动画，或将暂停状态切换为播放状态，或重新播放上一个正在播放的动画。 
	 * @param playTimes 播放次数。 [-1: 使用动画数据默认值, 0: 无限循环播放, [1~N]: 循环播放 N 次]
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 3.0
	 */
	public function play(animationName:String = null, playTimes:Int = -1):AnimationState
	{
		_animationConfig.clear();
		_animationConfig.playTimes = playTimes;
		_animationConfig.fadeInTime = 0.0;
		_animationConfig.animationName = animationName;
		
		if (animationName != null) 
		{
			playConfig(_animationConfig);
		}
		else if (_lastAnimationState == null) 
		{
			inline var defaultAnimation:AnimationData = _armature.armatureData.defaultAnimation;
			if (defaultAnimation) 
			{
				_animationConfig.animationName = defaultAnimation.name;
				playConfig(_animationConfig);
			}
		}
		else if (!_isPlaying || (!_lastAnimationState.isPlaying && !_lastAnimationState.isCompleted)) 
		{
			_isPlaying = true;
			_lastAnimationState.play();
		}
		else 
		{
			_animationConfig.animationName = _lastAnimationState.name;
			playConfig(_animationConfig);
		}
		
		return _lastAnimationState;
	}
	/**
	 * @language zh_CN
	 * 从指定时间开始播放动画。
	 * @param animationName 动画数据的名称。
	 * @param time 开始时间。 (以秒为单位)
	 * @param playTimes 播放次数。 [-1: 使用动画数据默认值, 0: 无限循环播放, [1~N]: 循环播放 N 次]
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function gotoAndPlayByTime(animationName:String, time:Float = 0.0, playTimes:Int = -1):AnimationState
	{
		_animationConfig.clear();
		_animationConfig.playTimes = playTimes;
		_animationConfig.position = time;
		_animationConfig.fadeInTime = 0.0;
		_animationConfig.animationName = animationName;
		
		return playConfig(_animationConfig);
	}
	/**
	 * @language zh_CN
	 * 从指定帧开始播放动画。
	 * @param animationName 动画数据的名称。
	 * @param frame 帧。
	 * @param playTimes 播放次数。 [-1: 使用动画数据默认值, 0: 无限循环播放, [1~N]: 循环播放 N 次]
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function gotoAndPlayByFrame(animationName:String, frame:UInt = 0, playTimes:Int = -1):AnimationState
	{
		_animationConfig.clear();
		_animationConfig.playTimes = playTimes;
		_animationConfig.fadeInTime = 0.0;
		_animationConfig.animationName = animationName;
		
		inline var animationData:AnimationData = _animations[animationName];
		if (animationData != null) 
		{
			_animationConfig.position = animationData.duration * frame / animationData.frameCount;
		}
		
		return playConfig(_animationConfig);
	}
	/**
	 * @language zh_CN
	 * 从指定进度开始播放动画。
	 * @param animationName 动画数据的名称。
	 * @param progress 进度。 [0~1]
	 * @param playTimes 播放次数。 [-1: 使用动画数据默认值, 0: 无限循环播放, [1~N]: 循环播放 N 次]
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function gotoAndPlayByProgress(animationName:String, progress:Float = 0.0, playTimes:Int = -1):AnimationState
	{
		_animationConfig.clear();
		_animationConfig.playTimes = playTimes;
		_animationConfig.fadeInTime = 0.0;
		_animationConfig.animationName = animationName;
		
		inline var animationData:AnimationData = _animations[animationName];
		if (animationData != null) 
		{
			_animationConfig.position = animationData.duration * (progress > 0.0 ? progress : 0.0);
		}
		
		return playConfig(_animationConfig);
	}
	/**
	 * @language zh_CN
	 * 将动画停止到指定的时间。
	 * @param animationName 动画数据的名称。
	 * @param time 时间。 (以秒为单位)
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function gotoAndStopByTime(animationName:String, time:Float = 0.0):AnimationState
	{
		inline var animationState:AnimationState = gotoAndPlayByTime(animationName, time, 1);
		if (animationState != null) 
		{
			animationState.stop();
		}
		
		return animationState;
	}
	/**
	 * @language zh_CN
	 * 将动画停止到指定的帧。
	 * @param animationName 动画数据的名称。
	 * @param frame 帧。
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function gotoAndStopByFrame(animationName:String, frame:UInt = 0):AnimationState
	{
		inline var animationState:AnimationState = gotoAndPlayByFrame(animationName, frame, 1);
		if (animationState != null)
		{
			animationState.stop();
		}
		
		return animationState;
	}
	/**
	 * @language zh_CN
	 * 将动画停止到指定的进度。
	 * @param animationName 动画数据的名称。
	 * @param progress 进度。 [0 ~ 1]
	 * @returns 对应的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 4.5
	 */
	public function gotoAndStopByProgress(animationName:String, progress:Float = 0):AnimationState
	{
		inline var animationState:AnimationState = gotoAndPlayByProgress(animationName, progress, 1);
		if (animationState != null)
		{
			animationState.stop();
		}
		
		return animationState;
	}
	/**
	 * @language zh_CN
	 * 获取动画状态。
	 * @param animationName 动画状态的名称。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 3.0
	 */
	public function getState(animationName:String):AnimationState
	{
		var l:UInt = _animationStates.length;
		for (i in 0...l)
		{
			inline var animationState:AnimationState = _animationStates[i];
			if (animationState.name == animationName)
			{
				return animationState;
			}
		}
		
		return null;
	}
	/**
	 * @language zh_CN
	 * 是否包含动画数据。
	 * @param animationName 动画数据的名称。
	 * @see dragonBones.objects.AnimationData
	 * @version DragonBones 3.0
	 */
	public function hasAnimation(animationName:String):Bool
	{
		return _animations.exists(animationName);
	}
	/**
	 * @language zh_CN
	 * 动画是否处于播放状态。
	 * @version DragonBones 3.0
	 */
	public function get isPlaying():Bool
	{
		if (_animationStates.length > 1) 
		{
			return _isPlaying && !isCompleted;
		}
		else if (_lastAnimationState != null) 
		{
			return _isPlaying && _lastAnimationState.isPlaying;
		}
		
		return _isPlaying;
	}
	/**
	 * @language zh_CN
	 * 所有动画状态是否均已播放完毕。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 3.0
	 */
	public function get isCompleted():Bool
	{
		if (_lastAnimationState)
		{
			if (!_lastAnimationState.isCompleted)
			{
				return false;
			}
			
			var l:UInt = _animationStates.length;
			for (i in 0...l)
			{
				if (!_animationStates[i].isCompleted)
				{
					return false;
				}
			}
			
			return true;
		}
		
		return false;
	}
	/**
	 * @language zh_CN
	 * 上一个正在播放的动画状态的名称。
	 * @see #lastAnimationState
	 * @version DragonBones 3.0
	 */
	public function get lastAnimationName():String
	{
		return _lastAnimationState? _lastAnimationState.name: null; 
	}
	/**
	 * @language zh_CN
	 * 上一个正在播放的动画状态。
	 * @see dragonBones.animation.AnimationState
	 * @version DragonBones 3.0
	 */
	public function get lastAnimationState():AnimationState
	{
		return _lastAnimationState;
	}
	/**
	 * @language zh_CN
	 * 一个可以快速使用的动画配置实例。
	 * @see dragonBones.objects.AnimationConfig
	 * @version DragonBones 5.0
	 */
	public function get animationConfig(): AnimationConfig 
	{
		_animationConfig.clear();
		return _animationConfig;
	}
	/**
	 * @language zh_CN
	 * 所有动画数据名称。
	 * @see #animations
	 * @version DragonBones 4.5
	 */
	public function get animationNames():Vector<String>
	{
		return _animationNames;
	}
	/**
	 * @language zh_CN
	 * 所有的动画数据。
	 * @see dragonBones.objects.AnimationData
	 * @version DragonBones 4.5
	 */
	public function get animations():Dynamic
	{
		return _animations;
	}
	public function set animations(value:Dynamic):Void
	{
		if (_animations == value)
		{
			return;
		}
		
		_animationNames.length = 0;
		_animations = new Map();
		
		if (value != null)
		{
			for (k in value)
			{
				_animations[k] = value[k];
				_animationNames.push(k);
			}
		}
	}
}