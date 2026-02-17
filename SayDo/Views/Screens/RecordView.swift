//
//  RecordView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 16.02.26.
//

import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var store: TaskStore
    @StateObject private var vm = RecordViewModel()
    
    var body: some View {
        ZStack(alignment: .bottomTrailing){
            
            VStack(spacing: 16) {
                HStack{
                    Text("Текст из голосового")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Language", selection: $vm.language){
                        ForEach(SpeechLanguage.allCases) { lang in
                            Text(lang.title).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
                
                ScrollView{
                    Text(vm.transcript.isEmpty ? "Нажми «Запись» и говори…" : vm.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(height: 200)
                
                if let err = vm.errorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button{
                    let tasks = vm.makeTasks()
                    guard !tasks.isEmpty else { return }
                    store.add(tasks)
                    vm.transcript = ""
                    
                } label: {
                    Label("Добавить задачи", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.transcript.isEmpty)
               
                Spacer(minLength: 80)
            }
            .padding()
            FloatingMicButton(isRecording: vm.isRecording){
                vm.isRecording ? vm.stop() : vm.start()
            }
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
        
        .task {
            await vm.requestPermission()
        }
    }
}

#Preview {
    NavigationStack {
        RecordView()
            .environmentObject(TaskStore())
    }
}
