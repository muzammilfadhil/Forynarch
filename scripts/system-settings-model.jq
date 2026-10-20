def defaults: {vfr:true,fpsOverlay:false,vrr:0,naturalScroll:false,sensitivity:0,
keyboardLayout:"us",repeatRate:25,repeatDelay:600,idleLock:0,idleBlank:0,idleSleep:0,
windowGap:6,screenMargin:14,cornerRadius:10,
focusTiled:true,focusFloating:true,focusColor:"#96c8ff"};
# Validation is intentionally explicit, not an executable user expression.
def valid:
  . as $v |
  type=="object" and (.vfr|type)=="boolean" and (.fpsOverlay|type)=="boolean" and
  (.naturalScroll|type)=="boolean" and ([0,2]|index($v.vrr))!=null and
all([.windowGap,.screenMargin,.cornerRadius][]; type=="number" and floor==. and .>=0) and
  .windowGap<=40 and .screenMargin<=64 and .cornerRadius<=40 and
  (.focusTiled|type)=="boolean" and (.focusFloating|type)=="boolean" and
  (.focusColor|type)=="string" and (.focusColor|test("^#[0-9a-fA-F]{6}$")) and
  ([-1,-0.5,0,0.5,1]|index($v.sensitivity))!=null and
  (["us","gb","de","fr","es","br","jp","id"]|index($v.keyboardLayout))!=null and
  ([25,35,50,70]|index($v.repeatRate))!=null and
  ([250,400,600,800]|index($v.repeatDelay))!=null and
  ([0,300,600,900]|index($v.idleLock))!=null and
  ([0,300,600,900,1800]|index($v.idleBlank))!=null and
  ([0,900,1800,3600]|index($v.idleSleep))!=null and
  (.idleSleep==0 or .idleBlank==0 or .idleSleep>.idleBlank) and
  (.idleLock==0 or .idleBlank==0 or .idleLock<=.idleBlank) and
  (.idleLock==0 or .idleSleep==0 or .idleLock<.idleSleep);
(. // {}) as $provided | (defaults + $provided) as $v |
if ($v | valid) then $v else error("Invalid system preferences") end
