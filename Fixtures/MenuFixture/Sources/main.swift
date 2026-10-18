import AppKit

// A windowless app with fixed menus, read by IntegrationTests. Nothing here
// is shipped. The menus are built in code so the expected shortcuts live next
// to their definition in FixtureMenu.swift.

let application = NSApplication.shared
application.setActivationPolicy(.regular)
application.mainMenu = FixtureMenu.makeMainMenu()
application.run()
