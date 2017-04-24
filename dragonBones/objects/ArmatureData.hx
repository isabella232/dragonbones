package dragonBones.objects
{
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

import dragonBones.core.BaseObject;
import dragonBones.enum.ArmatureType;
import dragonBones.geom.Transform;

/**
 * @language zh_CN
 * 骨架数据。
 * @see dragonBones.Armature
 * @version DragonBones 3.0
 */
public class ArmatureData extends BaseObject
{
	private static function _onSortSlots(a:SlotData, b:SlotData):Int
	{
		return a.zOrder > b.zOrder? 1: -1;
	}
	/**
	 * @language zh_CN
	 * 动画帧率。
	 * @version DragonBones 3.0
	 */
	public var frameRate:UInt;
	/**
	 * @private
	 */
	public var type:Int;
	/**
	 * @private
	 */
	public var cacheFrameRate:UInt;
	/**
	 * @private
	 */
	public var scale:Float;
	/**
	 * @language zh_CN
	 * 数据名称。
	 * @version DragonBones 3.0
	 */
	public var name:String;
	/**
	 * @private
	 */
	public inline var aabb:Rectangle = new Rectangle();
	/**
	 * @language zh_CN
	 * 所有骨骼数据。
	 * @see dragonBones.objects.BoneData
	 * @version DragonBones 3.0
	 */
	public inline var bones:Object = {};
	/**
	 * @language zh_CN
	 * 所有插槽数据。
	 * @see dragonBones.objects.SlotData
	 * @version DragonBones 3.0
	 */
	public inline var slots:Object = {};
	/**
	 * @language zh_CN
	 * 所有皮肤数据。
	 * @see dragonBones.objects.SkinData
	 * @version DragonBones 3.0
	 */
	public inline var skins:Object = {};
	/**
	 * @language zh_CN
	 * 所有动画数据。
	 * @see dragonBones.objects.AnimationData
	 * @version DragonBones 3.0
	 */
	public inline var animations:Object = {};
	/**
	 * @private
	 */
	public inline var actions: Vector.<ActionData> = new Vector.<ActionData>();
	/**
	 * @language zh_CN
	 * 所属的龙骨数据。
	 * @see dragonBones.DragonBonesData
	 * @version DragonBones 4.5
	 */
	public var parent:DragonBonesData;
	/**
	 * @private
	 */
	public var userData: CustomData;
	
	private var _boneDirty:Bool;
	private var _slotDirty:Bool;
	private inline var _animationNames:Vector.<String> = new Vector.<String>();
	private inline var _sortedBones:Vector.<BoneData> = new Vector.<BoneData>();
	private inline var _sortedSlots:Vector.<SlotData> = new Vector.<SlotData>();
	private inline var _bonesChildren:Object = {};
	private var _defaultSkin:SkinData;
	private var _defaultAnimation:AnimationData;
	/**
	 * @private
	 */
	public function ArmatureData()
	{
		super(this);
	}
	/**
	 * @private
	 */
	override private function _onClear():Void
	{
		for (var k:String in bones)
		{
			(bones[k] as BoneData).returnToPool();
			delete bones[k];
		}
		
		for (k in slots)
		{
			(slots[k] as SlotData).returnToPool();
			delete slots[k];
		}
		
		for (k in skins)
		{
			(skins[k] as SkinData).returnToPool();
			delete skins[k];
		}
		
		for (k in animations)
		{
			(animations[k] as AnimationData).returnToPool();
			delete animations[k];
		}
		
		for (var i:UInt = 0, l:UInt = actions.length; i < l; ++i)
		{
			actions[i].returnToPool();
		}
		
		for (k in _bonesChildren)
		{
			delete _bonesChildren[k];
		}
		
		if (userData) 
		{
			userData.returnToPool();
		}
		
		frameRate = 0;
		type = ArmatureType.None;
		cacheFrameRate = 0;
		scale = 1.0;
		name = null;
		aabb.x = 0.0;
		aabb.y = 0.0;
		aabb.width = 0.0;
		aabb.height = 0.0;
		//bones.clear();
		//slots.clear();
		//skins.clear();
		//animations.clear();
		actions.length = 0;
		parent = null;
		userData = null;
		
		_boneDirty = false;
		_slotDirty = false;
		_animationNames.length = 0;
		_sortedBones.length = 0;
		_sortedSlots.length = 0;
		_defaultSkin = null;
		_defaultAnimation = null;
	}
	
	private function _sortBones():Void
	{
		inline var total:UInt = _sortedBones.length;
		if (!total)
		{
			return;
		}
		
		inline var sortHelper:Vector.<BoneData> = _sortedBones.concat();
		var index:UInt = 0;
		var count:UInt = 0;
		
		_sortedBones.length = 0;
		
		while(count < total)
		{
			inline var bone:BoneData = sortHelper[index++];
			
			if (index >= total)
			{
				index = 0;
			}
			
			if (_sortedBones.indexOf(bone) >= 0)
			{
				continue;
			}
			
			if (bone.parent && _sortedBones.indexOf(bone.parent) < 0)
			{
				continue;
			}
			
			if (bone.ik && _sortedBones.indexOf(bone.ik) < 0)
			{
				continue;
			}
			
			if (bone.ik && bone.chain > 0 && bone.chainIndex == bone.chain)
			{
				_sortedBones.splice(_sortedBones.indexOf(bone.parent) + 1, 0, bone); // ik, parent, bone, children
			}
			else
			{
				_sortedBones.push(bone);
			}
			
			count++;
		}
	}
	
	private function _sortSlots():Void
	{
		_sortedSlots.sort(_onSortSlots);
	}
	/**
	 * @private
	 */
	public function cacheFrames(value:UInt):Void
	{
		if (cacheFrameRate > 0) 
		{
			return;
		}
		
		cacheFrameRate = frameRate;
		
		for each (var animation:AnimationData in animations) 
		{
			animation.cacheFrames(cacheFrameRate);
		}
	}
	/**
	 * @private
	 */
	public function setCacheFrame(globalTransformMatrix: Matrix, transform: Transform):Float {
		inline var dataArray:Vector.<Number> = parent.cachedFrames;
		inline var arrayOffset:UInt = dataArray.length;
		
		dataArray.length += 10;
		dataArray[arrayOffset] = globalTransformMatrix.a;
		dataArray[arrayOffset + 1] = globalTransformMatrix.b;
		dataArray[arrayOffset + 2] = globalTransformMatrix.c;
		dataArray[arrayOffset + 3] = globalTransformMatrix.d;
		dataArray[arrayOffset + 4] = globalTransformMatrix.tx;
		dataArray[arrayOffset + 5] = globalTransformMatrix.ty;
		dataArray[arrayOffset + 6] = transform.skewX;
		dataArray[arrayOffset + 7] = transform.skewY;
		dataArray[arrayOffset + 8] = transform.scaleX;
		dataArray[arrayOffset + 9] = transform.scaleY;
		
		return arrayOffset;
	}
	/**
	 * @private
	 */
	public function getCacheFrame(globalTransformMatrix: Matrix, transform: Transform, arrayOffset:Float):Void {
		inline var dataArray:Vector.<Number> = parent.cachedFrames;
		
		globalTransformMatrix.a = dataArray[arrayOffset];
		globalTransformMatrix.b = dataArray[arrayOffset + 1];
		globalTransformMatrix.c = dataArray[arrayOffset + 2];
		globalTransformMatrix.d = dataArray[arrayOffset + 3];
		globalTransformMatrix.tx = dataArray[arrayOffset + 4];
		globalTransformMatrix.ty = dataArray[arrayOffset + 5];
		transform.skewX = dataArray[arrayOffset + 6];
		transform.skewY = dataArray[arrayOffset + 7];
		transform.scaleX = dataArray[arrayOffset + 8];
		transform.scaleY = dataArray[arrayOffset + 9];
	}
	/**
	 * @private
	 */
	public function addBone(value:BoneData, parentName:String):Void
	{
		if (value && value.name && !bones[value.name])
		{
			if (parentName)
			{
				inline var parent:BoneData = getBone(parentName);
				if (parent)
				{
					value.parent = parent;
				}
				else
				{
					(_bonesChildren[parentName] = _bonesChildren[parentName] || new Vector.<BoneData>()).push(value);
				}
			}
			
			inline var children:Vector.<BoneData> = _bonesChildren[value.name];
			if (children)
			{
				for (var i:UInt = 0, l :UInt= children.length; i < l; ++i)
				{
					children[i].parent = value;
				}
				
				delete _bonesChildren[value.name];
			}
			
			bones[value.name] = value;
			_sortedBones.push(value);
			
			_boneDirty = true;
		}
		else
		{
			throw new ArgumentError();
		}
	}
	/**
	 * @private
	 */
	public function addSlot(value:SlotData):Void
	{
		if (value && value.name && !slots[value.name])
		{
			slots[value.name] = value;
			_sortedSlots.push(value);
			
			_slotDirty = true;
		}
		else
		{
			throw new ArgumentError();
		}
	}
	/**
	 * @private
	 */
	public function addSkin(value:SkinData):Void
	{
		if (value && value.name && !skins[value.name])
		{
			skins[value.name] = value;
			
			if (!_defaultSkin)
			{
				_defaultSkin = value;
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
	public function addAnimation(value:AnimationData):Void
	{
		if (value && value.name && !animations[value.name])
		{
			animations[value.name] = value;
			_animationNames.push(value.name);
			
			if (!_defaultAnimation)
			{
				_defaultAnimation = value;
			}
		}
		else
		{
			throw new ArgumentError();
		}
	}
	/**
	 * @language zh_CN
	 * 获取骨骼数据。
	 * @param name 骨骼数据名称。
	 * @see dragonBones.objects.BoneData
	 * @version DragonBones 3.0
	 */
	public function getBone(name:String):BoneData
	{
		return bones[name] as BoneData;
	}
	/**
	 * @language zh_CN
	 * 获取插槽数据。
	 * @param name 插槽数据名称。
	 * @see dragonBones.objects.SlotData
	 * @version DragonBones 3.0
	 */
	public function getSlot(name:String):SlotData
	{
		return slots[name] as SlotData;
	}
	/**
	 * @private
	 */
	public function getSkin(name:String):SkinData
	{
		return name? (skins[name] as SkinData): _defaultSkin;
	}
	/**
	 * @language zh_CN
	 * 获取动画数据。
	 * @param name 动画数据名称。
	 * @see dragonBones.objects.AnimationData
	 * @version DragonBones 3.0
	 */
	public function getAnimation(name:String):AnimationData
	{
		return name? (animations[name] as AnimationData): _defaultAnimation;
	}
	/**
	 * @language zh_CN
	 * 所有动画数据名称。
	 * @see #armatures
	 * @version DragonBones 3.0
	 */
	public function get animationNames(): Vector.<String> 
	{
		return _animationNames;
	}
	/**
	 * @private
	 */
	public function get sortedBones():Vector.<BoneData>
	{
		if (_boneDirty)
		{
			_boneDirty = false;
			_sortBones();
		}
		
		return _sortedBones;
	}
	/**
	 * @private
	 */
	public function get sortedSlots():Vector.<SlotData>
	{
		if (_slotDirty)
		{
			_slotDirty = false;
			_sortSlots();
		}
		
		return _sortedSlots;
	}
	/**
	 * @private
	 */
	public function get defaultSkin():SkinData
	{
		return _defaultSkin;
	}
	/**
	 * @language zh_CN
	 * 获取默认的动画数据。
	 * @see dragonBones.objects.AnimationData
	 * @version DragonBones 4.5
	 */
	public function get defaultAnimation():AnimationData
	{
		return _defaultAnimation;
	}
}
}