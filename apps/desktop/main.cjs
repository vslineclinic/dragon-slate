const path = require('node:path');
const { app, BrowserWindow, Menu, shell } = require('electron');

function openExternalLink(url) {
  const target = URL.parse(url);
  if (target?.protocol === 'http:' || target?.protocol === 'https:') {
    shell.openExternal(target.href).catch((error) => console.error(error));
  }
}

function createWindow() {
  const window = new BrowserWindow({
    width: 1280,
    height: 720,
    minWidth: 960,
    minHeight: 540,
    backgroundColor: '#0e1016',
    title: 'Wyrmslot',
    resizable: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  window.webContents.on('before-input-event', (event, input) => {
    if (input.type !== 'keyDown') return;

    if (input.key === 'F11') {
      event.preventDefault();
      if (!input.isAutoRepeat) window.setFullScreen(!window.isFullScreen());
    } else if (input.key === 'Escape' && window.isFullScreen()) {
      event.preventDefault();
      window.setFullScreen(false);
    }
  });

  window.webContents.setWindowOpenHandler(({ url }) => {
    openExternalLink(url);
    return { action: 'deny' };
  });

  window.webContents.on('will-navigate', (event) => {
    event.preventDefault();
    openExternalLink(event.url);
  });

  const indexPath = app.isPackaged
    ? path.join(app.getAppPath(), 'dist/index.html')
    : path.join(__dirname, '../../dist/index.html');
  window.loadFile(indexPath).catch((error) => console.error(error));
}

if (app.requestSingleInstanceLock()) {
  app.on('second-instance', () => {
    const [window] = BrowserWindow.getAllWindows();
    if (!window) return;

    if (window.isMinimized()) window.restore();
    window.focus();
  });

  app.whenReady().then(() => {
    Menu.setApplicationMenu(null);
    createWindow();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
  });

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
  });
} else {
  app.quit();
}
