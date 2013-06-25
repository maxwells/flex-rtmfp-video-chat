package com.github.maxwells.voip
{
    import flash.events.NetStatusEvent;
    import flash.media.Camera;
    import flash.media.Microphone;
    import flash.media.SoundCodec;
    import flash.media.Video;
    import flash.net.GroupSpecifier;
    import flash.net.NetConnection;
    import flash.net.NetGroup;
    import flash.net.NetStream;
    
    public class VoipService
    {
        private var _server:String;
        private var _netConnection:NetConnection; 
        private var _groupSpecifierId:String;
        private var _groupSpecifier:GroupSpecifier;
        private var _netGroup:NetGroup;
        private var _netStream:NetStream;
        private var _playNetStream:Array = new Array();
        private var _neighbors:Number = 0;
        private var Trace:Function;
        private var _video:Video;
        private var _mic:Microphone;
        private var _camera:Camera;
        private var _addPlayNetStream:Function;
        private var _dropPlayNetStream:Function;
        
        public var connected:Boolean = false;
        
        public function VoipService(server:String, groupSpecifierId:String, traceFunction:Function, addPlayNetStream:Function, dropPlayNetStream:Function)
        {
            _server = server;
            _groupSpecifierId = groupSpecifierId;
            Trace = traceFunction;
            _addPlayNetStream = addPlayNetStream;
            _dropPlayNetStream = dropPlayNetStream;
        }
        
        // Connect to the URL passed in the constructor.
        public function connect():void {
            _netConnection = new NetConnection();
            _netConnection.addEventListener( NetStatusEvent.NET_STATUS, netStatusHandler ); 
            _netConnection.connect(_server);
        }
        
        private function netStatusHandler(e:NetStatusEvent):void {
            Trace("netStatusHandler received NetStatusEvent with code: " + e.info.code);
            switch (e.info.code)
            {
                case 'NetConnection.Connect.Success':
                    onConnect();
                    break;
                
                case "NetConnection.Connect.Closed":
                case "NetConnection.Connect.Failed":
                case "NetConnection.Connect.Rejected":
                case "NetConnection.Connect.AppShutdown":
                case "NetConnection.Connect.InvalidApp":
                    onDisconnect();
                    break;
                
                // NetGroup
                case 'NetGroup.Connect.Success':
                    onConnectGroup();
                    break;
                case 'NetGroup.Neighbor.Connect':
                    _neighbors++;
                    Trace(_neighbors+" neighbor(s)");
                    break;
                case 'NetGroup.Neighbor.Disconnect':
                    _neighbors--;
                    Trace(_neighbors+" neighbor(s)");
                    break;
                
                case 'NetGroup.MulticastStream.PublishNotify':
                    onNeighborPublish(e.info.name);
                    break;
                case 'NetGroup.MulticastStream.UnpublishNotify':
                    onNeighborUnpublish(e.info.name);
                    break;
                
                // NetStream
                case "NetStream.Connect.Success":
                    onNetStreamConnect();
                    break;
                
                case 'NetStream.Play.Failed':
                    Trace("Play failed because: " + e.info.description);
                    break;
                
                case "NetStream.Connect.Rejected":
                case "NetStream.Connect.Failed":
                    break;
                
                default:
                    break;
            }
        }
        
        private function netGroupStatusHandler(e:NetStatusEvent):void {
            Trace("netGroupStatusHandler received: "+e.toString());
        }
        
        private function onConnect():void {
            connected = true;
            
            var groupSpecifier:GroupSpecifier; 
            _groupSpecifier = new GroupSpecifier(_groupSpecifierId);
            _groupSpecifier.postingEnabled = true;
            _groupSpecifier.serverChannelEnabled = true;
            _groupSpecifier.multicastEnabled = true;
            _netGroup = new NetGroup(_netConnection, _groupSpecifier.groupspecWithAuthorizations());
            _netGroup.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
            _netStream = new NetStream(_netConnection, _groupSpecifier.groupspecWithAuthorizations());
            _netStream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
            
            Trace("Joined \"" + _groupSpecifier.groupspecWithAuthorizations() + "\".");
        }
        
        private function onDisconnect():void {
            connected = false;
            Trace("onDisconnect();\n\nYou're done, son.");
        }
        
        private function onConnectGroup():void {
            var object:Object = new Object();
            object.message = "Hey, you!";
            _netGroup.sendToAllNeighbors(object);
        }
        
        private function onNetStreamConnect():void
        {
        }
        
        public function publish():void {
            _netStream.client = this;
            
            _mic = Microphone.getMicrophone();
            _camera = Camera.getCamera();
            
            if(_mic)
            {
                _mic.codec = SoundCodec.SPEEX;
                _mic.setSilenceLevel(0);
                
                _netStream.attachAudio(_mic);
                
                Trace("got microphone\n");
            }
            var camera:Camera = Camera.getCamera();
            if(camera)
            {
                camera.setMode(320, 240, 10);
                camera.setQuality(30000, 0);
                camera.setKeyFrameInterval(15);
                
                _netStream.attachCamera(camera);
                
                Trace("got camera\n");
            }
            
            Trace("Publishing Stream: stream"+_neighbors);
            
            _netStream.publish("stream"+_neighbors);
        }
        
        private function onNeighborPublish(streamName:String):void {
            Trace("playing NetStream: " + streamName);
            _playNetStream[streamName] = new NetStream(_netConnection, _groupSpecifier.groupspecWithAuthorizations());
            _playNetStream[streamName].play(streamName);
            _addPlayNetStream(streamName, _playNetStream[streamName]);
        }
        
        private function onNeighborUnpublish(streamName:String):void {
            Trace("Dropping NetStream: "+streamName);
            _dropPlayNetStream(streamName);
            _playNetStream[streamName] = null;
        }
        
    }
}