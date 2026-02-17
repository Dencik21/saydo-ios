//
//  RecordView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 16.02.26.
//

import SwiftUI

struct RecordView: View {
    @StateObject private var vm = RecordViewModel()
    var body: some View {
        VStack(spacing: 16){
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
            }
           
            ScrollView{
                Text(vm.transcript.isEmpty ? "Нажми «Запись» и говори…" : vm.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 180)
            
            if let err = vm.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button{
                vm.isRecording ? vm.stop() : vm.start()
            } label: {
                Label(vm.isRecording ? "Стоп" : "Запись",
                      systemImage: vm.isRecording ? "stop.circle" : "mic.fill")
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            NavigationLink("В задачи") {
                TaskListView(tasks: vm.makeTasks())
            }
            .buttonStyle(.bordered)
            .disabled(vm.transcript.isEmpty)
             Spacer()
        }
        .padding()
        .task {
            await vm.requestPermission()
        }
    }
}

#Preview {
    RecordView()
}
