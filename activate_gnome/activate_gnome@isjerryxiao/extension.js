/* extension.js
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import St from 'gi://St'
import * as Main from 'resource:///org/gnome/shell/ui/main.js'
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js'
import GLib from 'gi://GLib'

export default class ActivateGnomeExtension extends Extension {
    constructor(metadata) {
        super(metadata)
        this.labels = []
        this.settings = null
        this.handlers = []
        this.settings_get = (method, key) => this.settings[method](key) || this.settings.get_default_value(key)[method]()
        this._timeout = null
    }

    _getIP() {
        // Executa 'hostname -I' para obter endereços IP
        let [ok, stdout, stderr, exitStatus] = GLib.spawn_command_line_sync('hostname -I');
        
        if (ok && exitStatus === 0 && stdout.length > 0) {
            // Decodifica a saída, remove espaços extras e pega o primeiro IP
            let ip_list = new TextDecoder().decode(stdout).trim().split(' ');
            return ip_list[0] || 'IP not found'; // Retorna o primeiro IP
        } else {
            this.log(`Failed to get IP: ${new TextDecoder().decode(stderr)}`);
            return 'IP not found';
        }
    }

    update() {
        // Texto é definido dinamicamente em vez de lido das configurações
        let text1 = GLib.get_host_name(); // Linha 1 é o hostname
        let text2 = this._getIP();           // Linha 2 é o IP
        
        // Lê outras configurações
        let vl2 = this.settings_get('get_double', 'l2-vertical')
        let hl2 = this.settings_get('get_double', 'l2-horizontal')
        let size1 = parseInt(this.settings_get('get_double', 'size-l1'))
        let size2 = parseInt(this.settings_get('get_double', 'size-l2'))
        let opacity = this.settings_get('get_double', 'opacity')

        this.cleanup()
        for (let monitor of Main.layoutManager.monitors) {
            let label_1 = new St.Label({style_class: 'label-1', text: text1, opacity})
            let label_2 = new St.Label({style_class: 'label-2', text: text2, opacity})
            label_1.set_style(`font-size: ${size1}px`)
            label_2.set_style(`font-size: ${size2}px`)
            
            // Alterado de {"affectsInputRegion": true} para {"affectsInputRegion": false}
            let params = {"trackFullscreen": false, "affectsStruts": false, "affectsInputRegion": false}
            
            // Alterado de addTopChrome para addChrome
            Main.layoutManager.addChrome(label_2, params)
            Main.layoutManager.addChrome(label_1, params)
            
            this.labels.push(label_1)
            this.labels.push(label_2)
            let h = Math.max(0, Math.floor(monitor.height * vl2 - label_2.height))
            let w = Math.max(0, Math.floor(monitor.width * hl2 - label_2.width))
            label_2.set_position(monitor.x + w, monitor.y + h)
            label_1.set_position(Math.min(monitor.x + w, monitor.x + monitor.width - label_1.width), monitor.y + h - label_1.height)
        }
    }

    cleanup() {
        for (let label of this.labels) {
            Main.layoutManager.removeChrome(label) // Não é mais 'removeChrome', mas removeChrome lida com ambos
            label.destroy()
        }
        this.labels = []
    }

    enable() {
        this.settings = this.getSettings()
        
        // Adiciona um handler para 'changed' apenas para configurações que ainda usamos
        this.handlers.push({
            owner: this.settings,
            id: this.settings.connect('changed', (settings, key) => {
                // Se uma configuração que não seja de texto mudar, atualize
                if (key !== 'text-l1' && key !== 'text-l2') {
                    this.update();
                }
            })
        });

        this.handlers.push({
            owner: Main.layoutManager,
            id: Main.layoutManager.connect('monitors-changed', () => this.update())
        })
        this.handlers.push({
            owner: Main.layoutManager,
            id: Main.layoutManager.connect('startup-complete', () => this.update())
        })

        // Adiciona um timer para atualizar o IP periodicamente (a cada 30 segundos)
        this._timeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 30000, () => {
            this.update();
            return GLib.SOURCE_CONTINUE; // Manter o timer ativo
        });

        if (!Main.layoutManager._startingUp) this.update()
    }

    disable() {
        // Remove o timer
        if (this._timeout) {
            GLib.source_remove(this._timeout);
            this._timeout = null;
        }

        this.cleanup()
        for (let handler of this.handlers) {
            handler.owner.disconnect(handler.id)
        }
        this.handlers = []
        this.settings = null
    }
}