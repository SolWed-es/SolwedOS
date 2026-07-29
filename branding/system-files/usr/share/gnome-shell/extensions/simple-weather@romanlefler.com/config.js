/*
    Copyright 2025 Roman Lefler

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
import GLib from "gi://GLib";
import { DistanceUnits, PressureUnits, RainMeasurementUnits, SpeedUnits, TempUnits } from "./units.js";
import { Location } from "./location.js";
import { WeatherProviderNames } from "./providers/provider.js";
import { Details } from "./details.js";
export var UnitPreset;
(function (UnitPreset) {
    UnitPreset[UnitPreset["Custom"] = 0] = "Custom";
    UnitPreset[UnitPreset["US"] = 1] = "US";
    UnitPreset[UnitPreset["UK"] = 2] = "UK";
    UnitPreset[UnitPreset["Metric"] = 3] = "Metric";
    UnitPreset[UnitPreset["Nordic"] = 4] = "Nordic";
})(UnitPreset || (UnitPreset = {}));
export class Config {
    #systemSettings;
    #settings;
    #handlerIds;
    constructor(settings, systemSettings = null) {
        this.#systemSettings = systemSettings;
        this.#settings = settings;
        this.#handlerIds = [];
    }
    free() {
        while (this.#handlerIds.length > 0) {
            const id = this.#handlerIds.pop();
            this.#settings?.disconnect(id);
        }
        // @ts-ignore
        this.#settings = undefined;
    }
    getTempUnit() {
        return this.#returnUnit("temp-unit", { us: TempUnits.Fahrenheit, metric: TempUnits.Celsius });
    }
    onTempUnitChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "temp-unit" || key === "unit-preset")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getLocations() {
        const gVariant = this.#settings.get_value("locations");
        const stringArr = readGTypeAS(gVariant);
        const locArr = stringArr.map(k => Location.parse(k));
        const filtered = locArr.filter(l => l !== null);
        if (filtered.length === 0) {
            const newLoc = Location.newHere();
            filtered.push(newLoc);
        }
        return filtered;
    }
    onLocationsChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "locations")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getMainLocation() {
        const inx = this.#settings.get_int64("main-location-index");
        const arr = this.getLocations();
        return arr[inx] ?? arr[0];
    }
    onMainLocationChanged(callback) {
        // Using change-event instead of changed makes sure
        // that the callback isn't double-fired since either
        // key causes a change
        const id = this.#settings.connect("change-event", (_, quarks) => {
            // Returning false continues to call changed events
            if (!quarks)
                return false;
            for (let q of quarks) {
                const s = GLib.quark_to_string(q);
                if (s === "locations" || s === "main-location-index") {
                    callback();
                    return false;
                }
            }
            return false;
        });
        this.#handlerIds.push(id);
    }
    getMainLocationIndex() {
        return this.#settings.get_int64("main-location-index");
    }
    onMainLocationIndexChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "main-location-index")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getMyLocationProvider() {
        const val = this.#settings.get_enum("my-loc-provider");
        // Parche Solwed OS: el enum real tiene 4 valores (ipinfo.io=1,
        // geoclue=2, disable=3, ipapi.co=4), pero este clamp original solo
        // dejaba pasar 1-2 -- cualquier otro valor, incluido el propio
        // default del schema (ipapi.co=4), caía silenciosamente a
        // ipinfo.io, que usa un token compartido por todos los usuarios de
        // esta extensión y suele estar agotado. Ver 18-simple-weather.conf.
        if (val > 4 || val < 1)
            return 1;
        else
            return val;
    }
    onMyLocationProviderChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "my-loc-provider")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getMyLocationRefreshMin() {
        const val = this.#settings.get_double("my-loc-refresh-min");
        if (val < 10.0)
            return 10.0;
        else
            return val;
    }
    getDontCheckLocales() {
        return this.#settings.get_boolean("dont-check-locales");
    }
    getWeatherProvider() {
        const val = this.#settings.get_enum("weather-provider");
        if (val < 1 || val > WeatherProviderNames.length)
            return 1;
        else
            return val;
    }
    onWeatherProviderChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "weather-provider")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getSpeedUnit() {
        return this.#returnUnit("speed-unit", {
            us: SpeedUnits.Mph,
            uk: SpeedUnits.Mph,
            metric: SpeedUnits.Kph,
            nordic: SpeedUnits.Mps
        });
    }
    onSpeedUnitChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "speed-unit" || key === "unit-preset")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getDirectionUnit() {
        return this.#settings.get_enum("direction-unit");
    }
    onDirectionUnitChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "direction-unit" || key === "unit-preset")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getPressureUnit() {
        return this.#returnUnit("pressure-unit", { us: PressureUnits.InHg, metric: PressureUnits.HPa });
    }
    onPressureUnitChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "pressure-unit" || key === "unit-preset")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getRainMeasurementUnit() {
        return this.#returnUnit("rain-measurement-unit", { us: RainMeasurementUnits.In, metric: RainMeasurementUnits.Mm });
    }
    onRainMeasurementUnitChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "rain-measurement-unit" || key === "unit-preset")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getDistanceUnit() {
        return this.#returnUnit("distance-unit", { us: DistanceUnits.Mi, uk: DistanceUnits.Mi, metric: DistanceUnits.Km });
    }
    onDistanceUnitChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "distance-unit" || key === "unit-preset")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getHighContrast() {
        return this.#settings.get_boolean("high-contrast");
    }
    onHighContrastChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "high-contrast")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getShowSunTime() {
        return this.#settings.get_boolean("show-suntime");
    }
    onShowSunTimeChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "show-suntime") {
                callback(this.#settings.get_boolean("show-suntime"));
            }
        });
        this.#handlerIds.push(id);
    }
    getShowSunTimeAsCountdown() {
        return this.#settings.get_boolean("show-suntime-as-countdown");
    }
    onShowSunTimeAsCountdownChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "show-suntime-as-countdown") {
                callback(this.#settings.get_boolean("show-suntime-as-countdown"));
            }
        });
        this.#handlerIds.push(id);
    }
    getSecondaryPanelDetail() {
        const detail = this.#settings.get_string("secondary-panel-detail");
        if (!Object.values(Details).includes(detail))
            return null;
        else
            return detail;
    }
    onSecondaryPanelDetailChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "secondary-panel-detail")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getShowPanelIcon() {
        return this.#settings.get_boolean("show-panel-icon");
    }
    onShowPanelIconChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "show-panel-icon")
                callback();
        });
        this.#handlerIds.push(id);
    }
    is24HourClock() {
        if (!this.#systemSettings)
            return null;
        return this.#systemSettings.get_enum("clock-format") === 0;
    }
    onIs24HourClockChanged(callback) {
        if (!this.#systemSettings)
            return;
        const id = this.#systemSettings.connect("changed", (_, key) => {
            if (key === "clock-format")
                callback();
        });
        this.#handlerIds.push(id);
    }
    /**
     * Gets the details list.
     * Items are not sanitized and may not be in Details.
     * If value is severely malformed a string full of
     * "invalid" will be returned.
     * @returns Guaranteed to be an 8 item string array.
     */
    getDetailsList() {
        const gval = this.#settings.get_value("details-list");
        const strarr = readGTypeAS(gval);
        if (strarr.length !== 8) {
            const defVal = this.#settings.get_default_value("details-list");
            if (!defVal)
                return new Array(8).fill("invalid");
            const defStrarr = readGTypeAS(defVal);
            if (defStrarr.length !== 8)
                return new Array(8).fill("invalid");
            return defStrarr;
        }
        else
            return strarr;
    }
    onDetailsListChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "details-list") {
                callback();
            }
        });
        this.#handlerIds.push(id);
    }
    getPanelPosition() {
        const boxNum = this.#settings.get_enum("panel-box");
        const box = (["right", "center", "left"])[boxNum] ?? "right";
        const priority = this.#settings.get_int64("panel-priority");
        return {
            box: box,
            priority
        };
    }
    onPanelPositionChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "panel-box" || key === "panel-priority")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getPanelOffset() {
        return this.#settings.get_double("panel-offset") / 100;
    }
    onPanelOffsetChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "panel-offset")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getPanelDetail() {
        const detail = this.#settings.get_string("panel-detail");
        if (!Object.values(Details).includes(detail))
            return null;
        else
            return detail;
    }
    onPanelDetailChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "panel-detail")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getTheme() {
        return this.#settings.get_string("theme");
    }
    onThemeChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "theme")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getSymbolicIcons() {
        return this.#settings.get_boolean("symbolic-icons-panel");
    }
    onSymbolicIconsChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "symbolic-icons-panel")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getAlwaysPackagedIcons() {
        return this.#settings.get_boolean("always-packaged-icons");
    }
    onAlwaysPackagedIconsChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "always-packaged-icons")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getHideErrPopup() {
        return this.#settings.get_boolean("hide-err-popup");
    }
    getShowRefreshButton() {
        return this.#settings.get_boolean("show-refresh-button");
    }
    onShowRefreshButtonChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            if (key === "show-refresh-button")
                callback();
        });
        this.#handlerIds.push(id);
    }
    getUnitPreset() {
        return this.#settings.get_enum("unit-preset");
    }
    onAnyUnitChanged(callback) {
        const id = this.#settings.connect("changed", (_, key) => {
            const unitKeys = [
                "unit-preset", "temp-unit", "speed-unit", "pressure-unit",
                "rain-measurement-unit", "distance-unit", "direction-unit"
            ];
            if (unitKeys.includes(key))
                callback();
        });
        this.#handlerIds.push(id);
    }
    /**
     * Shorthand for checking unit presets and outputting appropriate value,
     * or otherwise checking settings via get_enum for a number.
     *
     * args.us Unit for US preset
     *
     * args.uk Unit for UK preset. If not specified falls back to metric.
     *
     * args.metric Unit for Metric preset
     *
     * @param getEnumKey Backup get_enum string key
     */
    #returnUnit(getEnumKey, args) {
        const preset = this.getUnitPreset();
        switch (preset) {
            case UnitPreset.US:
                if (args.us !== undefined)
                    return args.us;
                else
                    break;
            case UnitPreset.UK:
                if (args.uk !== undefined)
                    return args.uk;
                // Fall back to metric.
                if (args.metric !== undefined)
                    return args.metric;
                else
                    break;
            case UnitPreset.Metric:
                if (args.metric !== undefined)
                    return args.metric;
                else
                    break;
            case UnitPreset.Nordic:
                if (args.nordic !== undefined)
                    return args.nordic;
                // Fall back to metric.
                if (args.metric !== undefined)
                    return args.metric;
                else
                    break;
        }
        return this.#settings.get_enum(getEnumKey);
    }
}
function readGTypeAS(gvariant) {
    const len = gvariant.n_children();
    const arr = [];
    for (let i = 0; i < len; i++) {
        const gString = gvariant.get_child_value(i);
        const s = gString.get_string()[0];
        arr.push(s);
    }
    return arr;
}
export function writeGTypeAS(arr) {
    const gVariantArr = [];
    for (let k of arr) {
        const gv = GLib.Variant.new_string(k);
        gVariantArr.push(gv);
    }
    return GLib.Variant.new_array(new GLib.VariantType("s"), gVariantArr);
}
