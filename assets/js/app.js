// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/indies_shuffle"

// Funciones para manejar cookies
function setCookie(name, value, maxAge) {
  document.cookie = `${name}=${encodeURIComponent(value)}; max-age=${maxAge}; path=/; SameSite=Lax`;
}

function getCookie(name) {
  const nameEQ = name + "=";
  const ca = document.cookie.split(';');
  for(let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) === ' ') c = c.substring(1, c.length);
    if (c.indexOf(nameEQ) === 0) return decodeURIComponent(c.substring(nameEQ.length, c.length));
  }
  return null;
}

// Hooks personalizados
const hooks = {
  FindingTimer: {
    mounted() {
      console.log("⏱️ FindingTimer montado");
      // Duración en segundos (20 segundos)
      const FINDING_DURATION = 20;
      let timeLeft = FINDING_DURATION;

      // Actualizar el timer cada segundo
      const interval = setInterval(() => {
        timeLeft--;

        if (timeLeft <= 0) {
          clearInterval(interval);
          this.el.textContent = "0";
          console.log("⏱️ Timer completado");
        } else {
          this.el.textContent = timeLeft;
        }

        // Cambiar color cuando queden menos de 10 segundos
        if (timeLeft <= 10) {
          this.el.classList.remove("text-orange-600");
          this.el.classList.add("text-red-600");
        }
      }, 1000);

      // Limpiar el interval cuando el componente se desmonte
      this.handleEvent = () => {};
      this.destroyed = () => {
        clearInterval(interval);
        console.log("⏱️ FindingTimer desmontado");
      };
    }
  },

  GameAuthChecker: {
    mounted() {
      console.log("🎮 GameAuthChecker montado, verificando acceso al juego...");

      // Generar o recuperar indie_id persistente
      let indieId = localStorage.getItem("persistent_indie_id");
      if (!indieId) {
        // Generar nuevo indie_id persistente
        indieId = "indie#" + Math.floor(Math.random() * 900000 + 100000);
        localStorage.setItem("persistent_indie_id", indieId);
        console.log("🆔 Nuevo indie_id generado para juego:", indieId);
      } else {
        console.log("🆔 Indie_id recuperado para juego:", indieId);
      }

      // Enviar indie_id al servidor para inicializar el juego
      this.pushEvent("init_indie_id", { indie_id: indieId });
    }
  },

  AuthChecker: {
    mounted() {
      console.log("🔌 AuthChecker montado, verificando autenticación...");
      console.log("🍪 Todas las cookies:", document.cookie);
      
      // Buscar JWT token en cookie primero (prioridad máxima)
      const jwtToken = getCookie("indie_jwt_token");
      console.log("🔐 JWT Token encontrado:", jwtToken ? "SÍ (" + jwtToken.substring(0, 20) + "...)" : "NO");
      
      if (jwtToken) {
        // Enviar JWT para validación al servidor
        console.log("✅ JWT encontrado, enviando para validación...");
        this.pushEvent("validate_jwt", { jwt: jwtToken });
        return;
      }
      
      // Generar o recuperar indie_id persistente
      let indieId = localStorage.getItem("persistent_indie_id");
      if (!indieId) {
        // Generar nuevo indie_id persistente
        indieId = "indie#" + Math.floor(Math.random() * 900000 + 100000);
        localStorage.setItem("persistent_indie_id", indieId);
        console.log("🆔 Nuevo indie_id generado:", indieId);
      } else {
        console.log("🆔 Indie_id recuperado:", indieId);
      }
      
      // Enviar indie_id al servidor
      this.pushEvent("init_indie_id", { indie_id: indieId });
      
      // Fallback: usar localStorage para migración de usuarios existentes
      const storedName = localStorage.getItem("indies_name");
      const storedIndieId = localStorage.getItem("indies_id");
      const token = localStorage.getItem("indies_token") || crypto.randomUUID();
      
      console.log("💾 localStorage - name:", storedName, "id:", storedIndieId);
      
      if (storedName && storedIndieId) {
        // Si hay datos en localStorage, migrar a JWT
        console.log("🔄 Migrando datos de localStorage a JWT...");
        this.pushEvent("init_token", {
          token: token,
          name: storedName,
          indie_id: storedIndieId
        });
      } else {
        console.log("👤 Usuario nuevo, mostrando formulario de registro...");
        this.pushEvent("no_auth_data", {});
      }
    }
  }
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => {
    return {
      _csrf_token: csrfToken,
      admin_token: localStorage.getItem("admin_token")
    }
  },
  hooks: {...colocatedHooks, ...hooks},
  // Configuración de reconexión automática
  reconnectAfterMs: (tries) => {
    // Backoff exponencial: 100ms, 500ms, 1s, 2s, 5s, luego 10s
    if (tries < 3) return [100, 500, 1000][tries];
    if (tries < 5) return [2000, 5000][tries - 3];
    return 10000; // Máximo 10 segundos
  },
  timeout: 20000, // 20 segundos de timeout
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// === Indicador de Conexión ===
// Crear el indicador de conexión
function createConnectionIndicator() {
  const indicator = document.createElement('div');
  indicator.id = 'connection-indicator';
  indicator.style.cssText = `
    position: fixed;
    top: 16px;
    left: 16px;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background-color: #10b981;
    box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
    z-index: 9999;
    transition: all 0.3s ease;
  `;
  indicator.title = 'Conectado';
  document.body.appendChild(indicator);
  return indicator;
}

function setConnectionStatus(connected) {
  let indicator = document.getElementById('connection-indicator');
  if (!indicator) {
    indicator = createConnectionIndicator();
  }

  if (connected) {
    indicator.style.backgroundColor = '#10b981'; // green-500
    indicator.style.boxShadow = '0 0 0 0 rgba(16, 185, 129, 0.7)';
    indicator.title = 'Conectado';
    // Animación de pulso cuando se conecta
    indicator.style.animation = 'none';
    setTimeout(() => {
      indicator.style.animation = 'pulse-once 0.5s ease-out';
    }, 10);
  } else {
    indicator.style.backgroundColor = '#ef4444'; // red-500
    indicator.style.boxShadow = '0 0 8px rgba(239, 68, 68, 0.6)';
    indicator.style.animation = 'pulse-continuous 2s infinite';
    indicator.title = 'Desconectado - Reconectando...';
  }
}

// Estilos de animación
const style = document.createElement('style');
style.textContent = `
  @keyframes pulse-once {
    0%, 100% {
      box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
    }
    50% {
      box-shadow: 0 0 0 6px rgba(16, 185, 129, 0);
    }
  }

  @keyframes pulse-continuous {
    0%, 100% {
      box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
    }
    50% {
      box-shadow: 0 0 0 8px rgba(239, 68, 68, 0);
    }
  }
`;
document.head.appendChild(style);

// Escuchar eventos de conexión/desconexión
window.addEventListener("phx:page-loading-start", () => {
  console.log("🔄 Cargando página...");
});

window.addEventListener("phx:page-loading-stop", () => {
  console.log("✅ Página cargada");
  setConnectionStatus(true);
});

// Detectar cambios en el estado de conexión del socket
liveSocket.onOpen(() => {
  console.log("🟢 WebSocket conectado");
  setConnectionStatus(true);
});

liveSocket.onError(() => {
  console.log("🔴 WebSocket error");
  setConnectionStatus(false);
});

liveSocket.onClose(() => {
  console.log("🔴 WebSocket desconectado");
  setConnectionStatus(false);
});

// Crear indicador al cargar la página
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', createConnectionIndicator);
} else {
  createConnectionIndicator();
}

// Eventos para JWT
const maxAge = 60 * 60 * 6; // 6 horas

// Función para borrar cookies
function deleteCookie(name) {
  document.cookie = name + "=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; SameSite=Lax";
  console.log(`🗑️ Cookie ${name} eliminada`);
}

// Escuchar eventos para guardar JWT desde el servidor
window.addEventListener("phx:save-jwt-cookie", (e) => {
  const { jwt } = e.detail;
  console.log("💾 Recibido evento save-jwt-cookie con JWT:", jwt ? "SÍ" : "NO");
  if (jwt) {
    setCookie("indie_jwt_token", jwt, maxAge);
    console.log("🔐 JWT guardado en cookie:", jwt.substring(0, 20) + "...");
    console.log("🍪 Cookies después de guardar:", document.cookie);
    
    // Notificar a otras pestañas que hay un nuevo JWT
    localStorage.setItem("jwt_updated", Date.now().toString());
  }
});

// Escuchar eventos para limpiar toda la autenticación
window.addEventListener("phx:clear-all-auth", (e) => {
  console.log("🧹 Limpiando autenticación (manteniendo indie_id persistente)...");
  
  // Limpiar cookies
  deleteCookie("indie_jwt_token");
  
  // Limpiar localStorage EXCEPTO el indie_id persistente
  localStorage.removeItem("indies_name");
  localStorage.removeItem("indies_id");
  localStorage.removeItem("indies_token");
  localStorage.removeItem("jwt_updated");
  // NO eliminar "persistent_indie_id" - debe mantenerse
  
  console.log("✅ Autenticación limpiada (indie_id persistente mantenido)");
  console.log("🍪 Cookies después de limpiar:", document.cookie);
  console.log("🆔 Indie_id persistente:", localStorage.getItem("persistent_indie_id"));
});

// Eventos para tokens de admin
window.addEventListener("phx:set_admin_token", (e) => {
  const { token } = e.detail;
  console.log("🔐 Guardando token de admin...");
  if (token) {
    localStorage.setItem("admin_token", token);
    console.log("✅ Token de admin guardado");
  }
});

window.addEventListener("phx:clear_admin_token", (e) => {
  console.log("🗑️ Limpiando token de admin...");
  localStorage.removeItem("admin_token");
  console.log("✅ Token de admin eliminado");
});

// Escuchar cambios en localStorage para sincronizar entre pestañas
window.addEventListener("storage", (e) => {
  if (e.key === "jwt_updated") {
    console.log("🔄 Otra pestaña actualizó el JWT, recargando...");
    // Recargar la página para usar el nuevo JWT
    window.location.reload();
  }
});

// Guarda nombre e ID en localStorage cuando se actualizan (backward compatibility)
window.addEventListener("phx:update-local", (e) => {
  const detail = e.detail || {};
  if (detail.name) localStorage.setItem("indies_name", detail.name);
  if (detail.indie_id) localStorage.setItem("indies_id", detail.indie_id);
});

// Asegura que el token se envía en los formularios
window.addEventListener("phx:page-loading-start", () => {
  const input = document.querySelector("input[name='token']");
  if (input && localStorage.getItem("indies_token")) {
    input.value = localStorage.getItem("indies_token");
  }
});

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

