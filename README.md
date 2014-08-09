### Ultra Basic Flex RTMFP Video Chat

##### Purpose

To serve as a working reference or starting point for anyone interested in creating a multiuser RTMFP audio/video client based on the Cirrus rendezvous service. Could be easily repurposed to work with Adobe Media Server.

##### Example

[Here](http://maxwells.github.io/flex-rtmfp-video-chat.html)

##### Basic Explanation

Leverages RTMFP NetGroups to publish a stream and listen to when a new stream has been published by another user.

_Assume_: Users A, B, and C are connected to the Cirrus service with the same developer key and group id.

- When User A publishes a stream, Users B and C subscribe to that stream automatically.
- When User A stops publishing, the event triggers Users B and C to drop the corresponding NetStream instance

##### Real Implementation

- Should be backed up with RTMP(E)(T) failover solution, because the implicit UDP Hole Punching cannot deal with all firewall and networking issues. Any production system would require both an RTMFP rendezvous service as well as an RTMP(E)(T) failback, as well as some means of alerting all clients that the failback should take place. It's easy enough with the Adobe Media Server, which provides both. More thought would have to go into a joint OpenRTMFP & Red5/Wowza solution. [Good description in "Failover in case of firewall blocking" section](http://www.adobe.com/devnet/adobe-media-server/articles/real-time-collaboration.html)
- May require implemention of access control with NetStream.onPeerConnect() or AMS-side restriction
- Should implement a real workflow (eg. requiring users to be connected before trying to publish, providing a disconnect or unpublish function)
- Should prevent users from publishing same stream names (for this example, verification of uniqueness of username)
- Should spend some time tweaking the NetStream `multicastWindowDuration` as well as microphone and camera bitrates to achieve optimal latency/quality balance.

##### Building

a) Flash Builder

-- or --

b) Ant

NB: Be sure to point FLEX_HOME in `build.properties` at your Flex SDK

	$ ant
	
##### License

This project rocks and uses MIT-LICENSE. Copyright 2013 - Max Lahey
