using UnityEditor;
using UnityEngine;

namespace {{PREFIX}}.Editor.ProjectSetup
{
    /// <summary>
    /// Applies the project's default settings through the Editor API (Tools > Project Setup > Apply Defaults).
    /// ProjectSettings/*.asset files are deliberately not copied: their format changes between Unity versions, so overwriting them breaks settings or is silently ignored.
    /// Safe to run repeatedly. Switching to the Input System only takes effect after an Editor restart.
    /// </summary>
    public static class ApplyProjectSettings
    {
        // ---- Tune here (values filled in by the scaffold) ----
        private const string ProductName = "{{PRODUCT}}";
        private const string CompanyName = "{{COMPANY}}";
        private const UIOrientation Orientation = UIOrientation.{{ORIENTATION}};

        // Enter Play Mode: Domain Reload off (fast Play). In exchange, mutable statics are reset on Play (docs/coding-guidelines.md section 3).
        private static readonly bool DisableDomainReload = true;

        /// <summary>Applies every default and logs one Console line per changed group.</summary>
        [MenuItem("Tools/Project Setup/Apply Defaults")]
        public static void ApplyDefaults()
        {
            // Assets must be stored as YAML text for git diffs and merges to work.
            EditorSettings.serializationMode = SerializationMode.ForceText;
            VersionControlSettings.mode = "Visible Meta Files";
            Log("Asset Serialization = Force Text, Version Control = Visible Meta Files");

            PlayerSettings.productName = ProductName;
            PlayerSettings.companyName = CompanyName;
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.defaultInterfaceOrientation = Orientation;
            Log($"Product = {ProductName}, Company = {CompanyName}, Color Space = Linear, Orientation = {Orientation}");

            SetEnterPlayMode();
            var inputChanged = SetInputSystemOnly();

            // Writing settings to disk is left to Unity (File > Save Project, or on Editor exit). AssetDatabase.SaveAssets() is not called:
            // it would also save other assets the user is editing.
            if (inputChanged)
                Debug.LogWarning("[ProjectSetup] Active Input Handling switched to Input System only. Restart the Editor for it to take effect (settings are saved on exit).");
            Log("Done — use File > Save Project to write the settings files.");
        }

        /// <summary>Enables Enter Play Mode Options with only Domain Reload disabled (Scene Reload stays on). Set via serialized properties because the API name differs across versions.</summary>
        private static void SetEnterPlayMode()
        {
            var asset = GetSettingsAsset("ProjectSettings/EditorSettings.asset");
            if (asset == null)
            {
                Debug.LogWarning("[ProjectSetup] EditorSettings.asset not found. Set it manually in Project Settings > Editor > Enter Play Mode Settings.");
                return;
            }

            var so = new SerializedObject(asset);
            var enabled = so.FindProperty("m_EnterPlayModeOptionsEnabled");
            var options = so.FindProperty("m_EnterPlayModeOptions");
            if (enabled == null || options == null)
            {
                Debug.LogWarning("[ProjectSetup] This Unity version uses different Enter Play Mode property names. Set it manually in Project Settings > Editor.");
                return;
            }

            enabled.boolValue = DisableDomainReload;
            options.intValue = DisableDomainReload ? (int)EnterPlayModeOptions.DisableDomainReload : (int)EnterPlayModeOptions.None;
            so.ApplyModifiedPropertiesWithoutUndo();
            Log(DisableDomainReload ? "Enter Play Mode = Domain Reload off, Scene Reload on" : "Enter Play Mode = default (both reload)");
        }

        /// <summary>Sets Active Input Handling to Input System only (1). There is no public API, so a serialized property is used. Returns true if it changed.</summary>
        private static bool SetInputSystemOnly()
        {
            var asset = GetSettingsAsset("ProjectSettings/ProjectSettings.asset");
            var so = asset != null ? new SerializedObject(asset) : null;
            var handler = so?.FindProperty("activeInputHandler");
            if (handler == null)
            {
                Debug.LogWarning("[ProjectSetup] activeInputHandler not found. Set Project Settings > Player > Active Input Handling to 'Input System Package (New)' manually.");
                return false;
            }

            if (handler.intValue == 1)
            {
                Log("Active Input Handling = Input System only (already set)");
                return false;
            }

            handler.intValue = 1;
            so.ApplyModifiedPropertiesWithoutUndo();
            Log("Active Input Handling = Input System only");
            return true;
        }

        private static Object GetSettingsAsset(string path)
        {
            var assets = AssetDatabase.LoadAllAssetsAtPath(path);
            return assets != null && assets.Length > 0 ? assets[0] : null;
        }

        private static void Log(string message) => Debug.Log($"[ProjectSetup] {message}");
    }
}
