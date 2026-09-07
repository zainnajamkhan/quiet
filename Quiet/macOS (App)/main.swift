//
//  main.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Cocoa

// An explicit entry point rather than @main on the delegate. The template relied on
// Main.storyboard to instantiate AppDelegate and connect it to NSApplication; once that
// storyboard was removed (it opened a second, competing window) nothing set the delegate,
// so applicationDidFinishLaunching never ran and no window ever appeared. Wiring it here
// makes startup independent of any nib or storyboard.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
