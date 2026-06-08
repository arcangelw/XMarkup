import AppKit

// 注意：不要加 @main，由 main.swift 手动启动
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 创建 NSSplitViewController
        let splitVC = NSSplitViewController()
        let listVC = ExamplesListViewController()
        let detailVC = ExampleDetailViewController()

        // 2. 配置侧边栏 item（全高度布局）
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: listVC)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 220
        sidebarItem.allowsFullHeightLayout = true

        let detailItem = NSSplitViewItem(viewController: detailVC)

        splitVC.addSplitViewItem(sidebarItem)
        splitVC.addSplitViewItem(detailItem)

        // 3. 创建窗口（必须包含 .fullSizeContentView）
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "XMarkup Demo (AppKit)"
        window.minSize = NSSize(width: 600, height: 400)
        window.titlebarAppearsTransparent = true
        window.center()

        // 4. 添加 toolbar（sidebarTrackingSeparator 是全高度侧边栏的关键）
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        window.toolbar = toolbar

        // 5. 设置 contentViewController 并强制初始尺寸
        window.contentViewController = splitVC
        window.setFrame(NSRect(x: 0, y: 0, width: 900, height: 600), display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        // 列表选中回调
        listVC.onSelect = { [weak detailVC] example in
            detailVC?.update(example: example)
        }
    }
}

// MARK: - NSToolbarDelegate

extension AppDelegate: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleSidebar:
            let item = NSToolbarItem(itemIdentifier: .toggleSidebar)
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            return item
        case .sidebarTrackingSeparator:
            return NSToolbarItem(itemIdentifier: .sidebarTrackingSeparator)
        default:
            return nil
        }
    }
}
