//
//  Date.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//


import Foundation

extension Date {
    func startOfDay(using calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
