package com.github.maxwells.rtmfp
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
    
    public class RtmfpService
    {
        private var _server:String;
        private var _username:String;
        private var _netConnection:NetConnection; 
        private var _groupSpecifierId:String;
        private var _groupSpecifier:GroupSpecifier;
        private var _netGroup:NetGroup;
        private var _publishNetStream:NetStream;
        private var _playNetStream:Array = new Array();
        private var _neighbors:Number = 0;
        private var Trace:Function;
        private var _video:Video;
        private var _mic:Microphone;
        private var _camera:Camera;
        private var _addPlayNetStream:Function;
        private var _dropPlayNetStream:Function;
        
        public var connected:Boolean = false;
        
        public function RtmfpService(server:String, groupSpecifierId:String, username:String, traceFunction:Function, addPlayNetStream:Function, dropPlayNetStream:Function)
        {
            _server = server;
            _groupSpecifierId = groupSpecifierId;
            _username = username;
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
        
        // Handle NetStatusEvents
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
        
        // Once connected to Cirrus, get introduced to rendezvous corresponding with _groupSpecifierId
        private function onConnect():void {
            connected = true;
            
            _groupSpecifier = new GroupSpecifier(_groupSpecifierId);
            _groupSpecifier.postingEnabled = true;
            _groupSpecifier.serverChannelEnabled = true;
            _groupSpecifier.multicastEnabled = true;
            
            _netGroup = new NetGroup(_netConnection, _groupSpecifier.groupspecWithAuthorizations());
            _netGroup.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
            
            _publishNetStream = new NetStream(_netConnection, _groupSpecifier.groupspecWithAuthorizations());
            _publishNetStream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
            
            Trace("Joined \"" + _groupSpecifier.groupspecWithAuthorizations() + "\".");
        }
        
        private function onDisconnect():void {
            connected = false;
            Trace("onDisconnect();\n\nYou're done, son.");
        }
        
        private function onNetStreamConnect():void
        {
        }
        
        // Grabs audio and video and publishes them to peers
        public function publish():void {
            _publishNetStream.client = this;
            
            _mic = Microphone.getEnhancedMicrophone();
            _camera = Camera.getCamera();
            
            if(_mic) {
                _mic.codec = SoundCodec.SPEEX;
                _mic.setSilenceLevel(0);
                _mic.framesPerPacket = 1;
                _mic.encodeQuality = 4;
                _publishNetStream.attachAudio(_mic);
            }
            
            if(_camera) {
                _camera.setMode(320, 240, 10);
                _camera.setQuality(14000, 0);
                _camera.setKeyFrameInterval(15);
                
                _publishNetStream.attachCamera(_camera);
            }
            
            Trace("Publishing Stream: stream"+_username);
            _publishNetStream.bufferTime = 0;
            _publishNetStream.multicastAvailabilitySendToAll = true;
            _publishNetStream.multicastWindowDuration = 0.1;
            
            _publishNetStream.publish("stream"+_username);
        }
        
        // Triggered when an RMTFP neighbor publishes a stream.
        // Creates a NetStream, plays it, and passes it back to the callback
        private function onNeighborPublish(streamName:String):void {
            Trace("playing NetStream: " + streamName);
            _playNetStream[streamName] = new NetStream(_netConnection, _groupSpecifier.groupspecWithAuthorizations());
            _playNetStream[streamName].bufferTime = 0;
            _playNetStream[streamName].play(streamName);
            _addPlayNetStream(streamName, _playNetStream[streamName]);
        }
        
        // Triggered when an RTMFP neighbor unpublishes a stream
        // Calls back and releases corresponding NetStream from memory
        private function onNeighborUnpublish(streamName:String):void {
            Trace("Dropping NetStream: "+streamName);
            _dropPlayNetStream(streamName);
            _playNetStream[streamName] = null;
        }
        
    }
}