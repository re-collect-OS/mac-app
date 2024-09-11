import SwiftUI
import Amplify
import AWSCognitoAuthPlugin
import Alamofire
import AWSPluginsCore

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var textOpacity = 0.0 // Start with 0 opacity
    @State private var isSigningIn = false // Track sign-in process
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack{
            VStack(alignment: .leading, spacing: 20) {
                
                Spacer()
                Image(colorScheme == .dark ? "onboardingicondark" : "onboardingiconlight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 90)
                
//                Text("Dev")
//                    .font(.system(size: 12))
//                    .padding(.vertical, 5)
//                    .padding(.horizontal, 10)
//                    .background(Color.red)
//                    .foregroundColor(.white)
//                    .clipShape(Capsule())
                
                HStack {
                    Text("Welcome to")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                    
                    Text("Sidecar")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(hex: "4240B9"))
                }
                
                Text("Everything and anything you need to reference to get anything done.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                if #available(macOS 14, *) {
                    TextField("Email", text: $username)
                        .frame(width: 300)
                        .font(.title3)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.extraLarge)
                    SecureField("Password", text: $password)
                        .frame(width: 300)
                        .font(.title3)
                        .controlSize(.extraLarge)
                        .textFieldStyle(.roundedBorder)
                        .overlay(
                            Group {
                                if isSigningIn {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                                .padding(.trailing, 10),
                            alignment: .trailing
                        )
                    
                        .onSubmit {
                            signIn()
                        }
                    if let message = authManager.loginMessage {
                                  Text(message)
                                      .foregroundColor(.red) // Display the login message prominently
                              }
                } else {
                    TextField("Email", text: $username)
                        .frame(width: 300)
                        .font(.title3)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                    SecureField("Password", text: $password)
                        .frame(width: 300)
                        .font(.title3)
                        .controlSize(.large)
                        .textFieldStyle(.roundedBorder)
                        .overlay(
                            Group {
                                if isSigningIn {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.mini)
                                    
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                                .padding(.trailing, 10),
                            alignment: .trailing
                        )
                        .onSubmit {
                            signIn()
                        }
                }
                
                
                Spacer()
            }.padding(.leading, 25).padding(.top, -80)
        Spacer()
        }
        
        .padding()
        .opacity(textOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                self.textOpacity = 1.0
            }
            Task {
                await authManager.checkUserState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }
    
    func signIn() {
        Task {
            isSigningIn = true
            await authManager.signIn(username: username, password: password)
            isSigningIn = false
        }
    }
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "060606") : Color(hex: "F0F0F0")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
        
        ContentView()
            .preferredColorScheme(.dark)
    }
}
