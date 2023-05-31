//
//  ContentView.swift
//  SwiftUI_MQTT
//
//  Created by Anoop M on 2021-01-19.
//

import SwiftUI
import CoreMotion

struct SensorData {
    var timestamp: Double
    var value: CMAcceleration
}

struct MessagesView: View {
    // TODO: Remove singleton
    @StateObject var mqttManager = MQTTManager.shared()
    var body: some View {
        NavigationView {
            MessageView()
        }
        .environmentObject(mqttManager)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MessagesView()
    }
}

struct MessageView: View {
    @State var topic: String = "all/values"
    @State var message: String = ""
    @EnvironmentObject private var mqttManager: MQTTManager

    @State private var showingClearAlert = false
    @State private var accelerometerData: [SensorData] = [SensorData(timestamp: 0, value: CMAcceleration(x: 0, y: 0, z: 0))]
    @State private var magnetometerData: [SensorData] = [SensorData(timestamp: 0, value: CMAcceleration(x: 0, y: 0, z: 0))]
    @State var TestID: String = "Test"
    @State var dist1 = 0.0
    @State var dist2 = 0.0
    @State var dist3 = 0.0
    @State var disg1 = 0.0
    @State var disg2 = 0.0
    @State var disg3 = 0.0
    
    @State var senden = true

    let motionManager = CMMotionManager()

    // Timer
    let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            ConnectionStatusBar(message: mqttManager.connectionStateMessage(), isConnected: mqttManager.isConnected())
            VStack {
                HStack {
                    MQTTTextField(placeHolderMessage: "Enter a topic to subscribe", isDisabled: !mqttManager.isConnected() || mqttManager.isSubscribed(), message: $topic)
                    Button(action: functionFor(state: mqttManager.currentAppState.appConnectionState)) {
                        Text(titleForSubscribButtonFrom(state: mqttManager.currentAppState.appConnectionState))
                            .font(.system(size: 14.0))
                    }.buttonStyle(BaseButtonStyle(foreground: .white, background: .green))
                        .frame(width: 100)
                        .disabled(!mqttManager.isConnected() || topic.isEmpty)
                }

                HStack {
                    Button(action: { sendDataToBroker() }) {
                        Text("Send").font(.body)
                    }.buttonStyle(BaseButtonStyle(foreground: .white, background: .green))
                        .frame(width: 80)
                        
                }
                
                HStack {
                    MQTTTextField(placeHolderMessage: "Enter TestID", isDisabled: !mqttManager.isConnected() || mqttManager.isSubscribed(), message: $TestID)
                    /*TextField(
                            "TestID",
                            text: $TestID
                    )*/
                }
                

                /*MessageHistoryTextView(text: $mqttManager.currentAppState.historyText
                ).frame(height: 150)*/

                // Sensordaten anzeigen
                HStack {
                    VStack {
                        Text("Gyroskop:")
                        Text("X: \(dist1, specifier: "%.2f")")
                        Text("Y: \(dist2, specifier: "%.2f")")
                        Text("Z: \(dist3, specifier: "%.2f")")
                    }
                    VStack {
                        Text("Magnetometer:")
                        Text("X: \(disg1, specifier: "%.2f")")
                        Text("Y: \(disg2, specifier: "%.2f")")
                        Text("Z: \(disg3, specifier: "%.2f")")
                    }
                }
            }.padding(EdgeInsets(top: 0, leading: 7, bottom: 0, trailing: 7))

            Spacer()

        }
        .navigationTitle("Messages")
        .navigationBarItems(
            trailing:
                HStack {

                    Button(action: {
                        if(senden)
                        {
                            startSensors()
                        } else if (!senden) {
                            senden = true
                        }
                        
                        
                        
                    }) {
                        Text("Start")
                    }

                    Button(action: {
                        //stopSensors()
                        //motionManager.stopAccelerometerUpdates()
                        //motionManager.stopMagnetometerUpdates()
                        senden = false
                    }) {
                        Text("Stop")
                    }

                    Button("Clear") {
                        accelerometerData = [SensorData(timestamp: 0, value: CMAcceleration(x: 0, y: 0, z: 0))]
                        magnetometerData = [SensorData(timestamp: 0, value: CMAcceleration(x: 0, y: 0, z: 0))]

                    }

                    NavigationLink(
                        destination: SettingsView(brokerAddress: mqttManager.currentHost() ?? ""),
                        label: {
                            Image(systemName: "gear")
                        })

                }

        )

        // Timer
        .onReceive(timer) { _ in
            // Füge hier den Code ein, der ausgeführt wird, wenn der Timer tickt
            if(mqttManager.isSubscribed() && senden) {
                datenanzeigen()
                sendDataToBroker()
                accelerometerData.removeAll()
                magnetometerData.removeAll()
            }
            
            if(!senden) {
                accelerometerData.removeAll()
                magnetometerData.removeAll()
            }
            
            
        }
    }

    func startSensors() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.005
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (data, error) in
                if let data = data {
                    let value = data.acceleration
                    let timestamp = data.timestamp
                    accelerometerData.append(SensorData(timestamp: timestamp, value: value))
                    
                }
            }
        }

        if motionManager.isMagnetometerAvailable {
            motionManager.magnetometerUpdateInterval = 0.005
            motionManager.startMagnetometerUpdates(to: OperationQueue.main) { (data, error) in
                if let data = data {
                    let value = CMAcceleration(x: data.magneticField.x, y: data.magneticField.y, z: data.magneticField.z)
                    let timestamp = data.timestamp
                    magnetometerData.append(SensorData(timestamp: timestamp, value: value))
                    
                }
            }
        }
    }

    func stopSensors() {
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
            
        }
        if motionManager.isMagnetometerActive {
            motionManager.stopMagnetometerUpdates()
        }
    }
    
    func datenanzeigen() {
        dist1 = magnetometerData.last?.value.x ?? 0.0
        dist2 = magnetometerData.last?.value.y ?? 0.0
        dist3 = magnetometerData.last?.value.z ?? 0.0
        disg1 = accelerometerData.last?.value.x ?? 0.0
        disg2 = accelerometerData.last?.value.y ?? 0.0
        disg3 = accelerometerData.last?.value.z ?? 0.0
    }

    private func subscribe(topic: String) {
        mqttManager.subscribe(topic: topic)
    }

    private func usubscribe() {
        mqttManager.unSubscribeFromCurrentTopic()
    }

    private func sendDataToBroker() {

        let t1 = magnetometerData.last?.value.x ?? 0.0
        let t2 = magnetometerData.last?.value.y ?? 0.0
        let t3 = magnetometerData.last?.value.z ?? 0.0
        let g1 = accelerometerData.last?.value.x ?? 0.0
        let g2 = accelerometerData.last?.value.y ?? 0.0
        let g3 = accelerometerData.last?.value.z ?? 0.0
        let datetime = Int(Date().timeIntervalSince1970 * 1000)

        let finalMessage = "\(t1):\(t2):\(t3):\(g1*9.81):\(g2*9.81):\(g3*9.81);\(datetime)%\(TestID)"

        mqttManager.publish(with: finalMessage)
        self.message = ""
    }

    private func titleForSubscribButtonFrom(state: MQTTAppConnectionState) -> String {
        switch state {
        case .connected, .connectedUnSubscribed, .disconnected, .connecting:
            return "Subscribe"
        case .connectedSubscribed:
            return "Unsubscribe"
        }
    }

    private func functionFor(state: MQTTAppConnectionState) -> () -> Void {
        switch state {
        case .connected, .connectedUnSubscribed, .disconnected, .connecting:
            return { subscribe(topic: topic) }
        case .connectedSubscribed:
            return { usubscribe() }
        }
    }
}
