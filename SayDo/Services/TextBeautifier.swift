//
//  TextBeautifier.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import Foundation

final class TextBeautifier {
    func beautify(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        let separators = [  " и потом ", " потом ", " затем ", " после этого ", " далее ", " потом же ",
                            " дальше ", " и дальше ", " еще ", " ещё ", " и еще ", " и ещё ",
                            " что еще ", " что ещё "]
        
        
        for s in separators {
            t = t.replacingOccurrences(of: s, with: ". ")
        }
        
        if let last = t.last, ".!?".contains(last) == false {
            t += "."
        }
        return t
    }
}
