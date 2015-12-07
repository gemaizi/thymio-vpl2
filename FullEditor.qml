import QtQuick 2.5
import QtQuick.Window 2.2
import QtGraphicalEffects 1.0

Rectangle {
	id: mainContainer

	RadialGradient {
			anchors.fill: parent
			gradient: Gradient {
				GradientStop { position: 0.0; color: "white" }
				GradientStop { position: 0.5; color: "#eaeced" }
				//GradientStop { position: 0.0; color: "#1e2551" }
				//GradientStop { position: 0.5; color: "#121729" }
			}
		}

	// container for main view
	PinchArea {
		id: pinchArea

		anchors.fill: parent

		property double prevTime: 0

		onPinchStarted: {
			prevTime = new Date().valueOf();
		}

		onPinchUpdated: {
			var deltaScale = pinch.scale - pinch.previousScale

			// adjust content pos due to scale
			if (scene.scale + deltaScale > 1e-1) {
				scene.x += (scene.x - pinch.center.x) * deltaScale / scene.scale;
				scene.y += (scene.y - pinch.center.y) * deltaScale / scene.scale;
				scene.scale += deltaScale;
			}

			// adjust content pos due to drag
			var now = new Date().valueOf();
			var dt = now - prevTime;
			var dx = pinch.center.x - pinch.previousCenter.x;
			var dy = pinch.center.y - pinch.previousCenter.y;
			scene.x += dx;
			scene.y += dy;
			//scene.vx = scene.vx * 0.6 + dx * 0.4 * dt;
			//scene.vy = scene.vy * 0.6 + dy * 0.4 * dt;
			prevTime = now;
		}

		onPinchFinished: {
			//accelerationTimer.running = true;
		}

		MouseArea {
			anchors.fill: parent
			drag.target: scene
			scrollGestureEnabled: false

			onWheel: {
				var deltaScale = scene.scale * wheel.angleDelta.y / 1200.;

				// adjust content pos due to scale
				if (scene.scale + deltaScale > 1e-1) {
					scene.x += (scene.x - mainContainer.width/2) * deltaScale / scene.scale;
					scene.y += (scene.y - mainContainer.height/2) * deltaScale / scene.scale;
					scene.scale += deltaScale;
				}
			}
		}

		Item {
			id: scene

			property int highestZ: 2

			property real vx: 0 // in px per millisecond
			property real vy: 0 // in px per millisecond

			// we use a timer to have some smooth effect
			// TODO: fixme
			Timer {
				id: accelerationTimer
				interval: 17
				repeat: true
				onTriggered: {
					x += (vx * interval) * 0.001;
					y += (vy * interval) * 0.001;
					vx *= 0.85;
					vy *= 0.85;
					if (Math.abs(vx) < 1 && Math.abs(vy) < 1)
					{
						running = false;
						vx = 0;
						vy = 0;
					}
					console.log(vx);
					console.log(vy);
				}
			}

			// container for all links
			Item {
				id: linkContainer
			}

			// container for all blocks
			Item {
				id: blockContainer

				// timer to desinterlace objects
				Timer {
					interval: 17
					repeat: true
					running: true

					function sign(v) {
						if (v > 0)
							return 1;
						else if (v < 0)
							return -1;
						else
							return 0;
					}

					onTriggered: {
						var i, j;
						// move all blocks too close
						for (i = 0; i < blockContainer.children.length; ++i) {
							for (j = 0; j < i; ++j) {
								var dx = blockContainer.children[i].x - blockContainer.children[j].x;
								var dy = blockContainer.children[i].y - blockContainer.children[j].y;
								var dist = Math.sqrt(dx*dx + dy*dy);
								if (dist < 310) {
									var normDist = dist;
									var factor = 100 / (normDist+1);
									blockContainer.children[i].x += sign(dx) * factor;
									blockContainer.children[j].x -= sign(dx) * factor;
									blockContainer.children[i].y += sign(dy) * factor;
									blockContainer.children[j].y -= sign(dy) * factor;
								}
							}
						}
					}
				}
			}

			property double prevTime: 0

			Drag.onDragStarted: {
				prevTime = new Date().valueOf();
				console.log("drag started");
			}

			BlockLink {
				id: blockLinkComponent
			}
			BlockLinkArrow {
				id: blockLinkArrowComponent
			}
		}
	}

	// add block
	Image {
		id: addBlock
		source: "images/addButton.svg"

		width: 128
		height: 128
		anchors.left: parent.left
		anchors.leftMargin: 20
		anchors.bottom: parent.bottom
		anchors.bottomMargin: 20

		Rectangle {
			id: dragTarget

			x: -64
			y: -64
			width: 256
			height: 256
			radius: 128
			color: "#70000000"

			visible: addBlockMouseArea.drag.active
		}

		MouseArea {
			id: addBlockMouseArea
			anchors.fill: parent
			drag.target: dragTarget
			onClicked: {
				if (editor.visible)
					return;
				var pos = mainContainer.mapToItem(blockContainer, mainContainer.width/2, mainContainer.height/2);
				createBlock(pos.x, pos.y);
			}
			onPressed: {
				if (editor.visible) {
					mouse.accepted  = false;
				} else {
					dragTarget.scale = scene.scale;
				}
			}
			onReleased: {
				if (!drag.active)
					return;
				// create block
				var pos = mapToItem(blockContainer, mouse.x, mouse.y);
				createBlock(pos.x, pos.y);
				// reset indicator
				dragTarget.x = -64;
				dragTarget.y = -64;
			}
			function createBlock(x, y) {
				var block = blockComponent.createObject(blockContainer, {
					x: x - 128 + Math.random(),
					y: y - 128 + Math.random(),
					definition: editor.definition,
					params: editor.params
				});
				editor.block = block;
			}
		}
	}

	Component {
		id: blockComponent
		Block {
		}
	}

	// delete block
	Rectangle {
		id: delBlock

		anchors.right: parent.right
		anchors.bottom: parent.bottom

		width: 96+40
		height: 96+40

		color: "transparent"

		Image {
			id: delBlockImage

			source: "images/trashDefault.svg"

			state: parent.state

			width: 96
			height: 96

			anchors.right: parent.right
			anchors.rightMargin: 20
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 20+16
		}

		state: "NORMAL"

		states: [
			State {
				name: "HIGHLIGHTED"
				PropertyChanges { target: delBlockImage; source: "images/trashOpen.svg"; }
			}
		]
	}

	// center view
	Image {
		id: backgroundImage
		source: "images/centerContent.svg"

		width: 80
		height: 80
		anchors.right: parent.right
		anchors.rightMargin: 20+16
		anchors.top: parent.top
		anchors.topMargin: 20+16

		MouseArea {
			anchors.fill: parent
			onClicked: {
				scene.x = mainContainer.width/2 - (blockContainer.childrenRect.x + blockContainer.childrenRect.width/2) * scene.scale;
				scene.y = mainContainer.height/2 - (blockContainer.childrenRect.y + blockContainer.childrenRect.height/2) * scene.scale;
			}
		}
	}

	// run and stop
	Image {
		id: runButton
		source: "images/playButton.svg"

		width: 128
		height: 128
		anchors.top: parent.top
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.topMargin: 20

		MouseArea {
			anchors.fill: parent
			onClicked: runButton.state == 'EDITING' ? runButton.state = "PLAYING" : runButton.state = 'EDITING';
		}

		state: "EDITING"

		states: [
			State {
				name: "PLAYING"
				PropertyChanges { target: runButton; source: "images/stopButton.svg"; }
			}
		]
	}

	// block editor
	Editor {
		id: editor
	}
}
