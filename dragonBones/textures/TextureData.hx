package dragonBones.textures
{
import openfl.geom.Rectangle;

import dragonBones.core.BaseObject;
import dragonBones.core.DragonBones;

/**
 * @private
 */
public class TextureData extends BaseObject
{
	public static function generateRectangle():Rectangle
	{
		return new Rectangle();
	}
	
	public var rotated:Bool;
	public var name:String;
	public inline var region:Rectangle = new Rectangle();
	public var frame:Rectangle;
	public var parent:TextureAtlasData;
	
	public function TextureData(self:TextureData)
	{
		super(this);
		
		if (self != this)
		{
			throw new Error(DragonBones.ABSTRACT_CLASS_ERROR);
		}
	}
	
	override private function _onClear():Void
	{
		rotated = false;
		name = null;
		region.x = 0.0;
		region.y = 0.0;
		region.width = 0.0;
		region.height = 0.0;
		frame = null;
		parent = null;
	}
	
	public function copyFrom(value: TextureData):Void 
	{
		rotated = value.rotated;
		name = value.name;
		
		if (frame == null && value.frame != null) 
		{
			frame = TextureData.generateRectangle();
		}
		else if (frame != null && value.frame == null) 
		{
			frame = null;
		}
		
		if (frame != null && value.frame != null) 
		{
			frame.copyFrom(value.frame);
		}
		
		parent = value.parent;
		region.copyFrom(value.region);
	}
}
}