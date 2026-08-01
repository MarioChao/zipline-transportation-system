--[[

About this folder:
Specify objects to be attached to the zipline.

You can add objects by:
- Parenting an ObjectValue referencing a Model or BasePart.
- Changing an ObjectValue's Value property to reference a Model or BasePart.

Note:
- Models will only be added if it has a PrimaryPart.
- Objects that are anchored or already in a zipline won't be added.

There are also config attributes (check ExampleObjectValue).
- Attach_AtParameter: the location to attach the object, with parameter determined by UseDistanceAsParameter.
- Attach_FromClient: if true, the object is attached from the client, else it is from the server.
- Attach_TraversePositiveDirection: if true, the object will traverse in the positive direction initially.
- Attach_UseDistanceAsParameter: if true, uses distance (studs) as the parameter, else uses route alpha.

This folder's children is checked every frame to look for objects to attach.
Once an object is attached successfully, the ObjectValue's Value property will be set to nil.

]]