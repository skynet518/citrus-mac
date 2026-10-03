import AppKit

@MainActor enum DesktopVerification {
    static func run(image:CGImage,source:URL,check:ExtendedVerification.Check) throws {
        let suite = "CitrusDesktopVerification.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let preferences = DesktopButtonPreferences(defaults:defaults)
        try check("desktop_preferences_defaults",preferences.visible && !preferences.desktopOnly && preferences.savedOrigin == nil,"Fresh installation shows a floating button.")
        preferences.visible = false; preferences.desktopOnly = true; preferences.save(origin:CGPoint(x:-200,y:88))
        let restored = DesktopButtonPreferences(defaults:defaults)
        try check("desktop_preferences_restart",!restored.visible && restored.desktopOnly && restored.savedOrigin == CGPoint(x:-200,y:88),"Visibility, layer and position survive reconstruction from saved defaults.")
        restored.resetPosition()
        try check("desktop_reset_preserves_preferences",restored.savedOrigin == nil && !restored.visible && restored.desktopOnly,"Resetting the position preserves chosen visibility and layer.")

        let main = CGRect(x:0,y:0,width:1440,height:875), second = CGRect(x:-1920,y:0,width:1920,height:1080)
        let negative = DesktopPlacement.restore(CGPoint(x:-1000,y:100),screens:[main,second])
        try check("desktop_negative_screen_restore",negative == CGPoint(x:-1000,y:100),"A button on a display left of the main display keeps its position.")
        let disconnected = DesktopPlacement.restore(CGPoint(x:-1000,y:100),screens:[main])
        try check("desktop_disconnected_screen_recovery",main.insetBy(dx:8,dy:8).contains(CGRect(origin:disconnected,size:CGSize(width:68,height:68))),"A removed display cannot strand the button off screen.")
        let invalid = DesktopPlacement.restore(CGPoint(x:CGFloat.nan,y:100),screens:[main])
        try check("desktop_invalid_saved_position",invalid == DesktopPlacement.restore(nil,screens:[main]),"Non-finite stored coordinates fall back to the default position.")
        let clamped = DesktopPlacement.clamp(CGPoint(x:3000,y:-100),to:main)
        try check("desktop_drag_bounds",clamped == CGPoint(x:1364,y:8),"Dragging past screen edges keeps the complete 68 pt button within the visible frame.")
        let origins = [CGPoint(x:8,y:8),CGPoint(x:1364,y:8),CGPoint(x:8,y:799),CGPoint(x:1364,y:799)]
        let clear = origins.allSatisfy { origin in
            let button = CGRect(origin:origin,size:CGSize(width:68,height:68))
            let frame = RadialGeometry.frame(center:DesktopPlacement.wheelCenter(button:button,screen:main),screen:main)
            return main.contains(frame) && !frame.intersects(button.insetBy(dx:-6,dy:-6))
        }
        try check("desktop_wheel_keeps_drop_target_clear",clear,"At all four corners the wheel stays on screen without covering the original drop target.")

        let state = RadialState(); state.urls = [source]; state.entry = .desktopButton
        state.setMode(tools:true); state.update(point:CGPoint(x:170,y:60),option:false)
        try check("desktop_tools_without_modifiers",state.tools && state.action == .tool(.compress),"A visible mode selection remains active as the pointer enters a tool sector.")
        state.setMode(tools:false); state.update(point:CGPoint(x:170,y:60),option:true)
        try check("desktop_formats_ignore_modifiers",!state.tools && state.action == .convert("webp"),"Option does not unexpectedly override the explicit format selection at the new entry.")
        state.update(point:CGPoint(x:170,y:170),option:false)
        let allowsStaging = state.allowsStaging && state.action == nil
        state.entry = .systemDrag
        try check("desktop_center_staging_is_scoped",allowsStaging && !state.allowsStaging,"Only the desktop button flow permits staging in the center; no conversion action is inferred there.")
        state.entry = .filePicker; state.setMode(tools:true); state.update(point:CGPoint(x:170,y:60),option:false)
        try check("picker_visible_mode_persists",state.tools && state.action == .tool(.compress),"File-picker mode switching works without holding Option.")
        state.entry = .desktopButton; state.setMode(tools:false); state.urls = [source,source.deletingPathExtension().appendingPathExtension("pdf")]
        try check("desktop_mixed_batch_common_formats",Set(state.actions.map(\.title)) == Set(["JPG","DOCX"]),"A PNG/PDF batch exposes only formats available to both.")

        let model = ImageEditorModel(tool:.crop,source:source,image:image)
        model.cropRect = CGRect(x:0.113,y:0.207,width:0.597,height:0.499); model.updateCropFields()
        let crop = try ImageRendering.crop(image,normalized:model.cropRect)
        try check("crop_fractional_fields_match_export",Int(model.widthText) == crop.width && Int(model.heightText) == crop.height && crop.width == 143 && crop.height == 160,"Fractional handle positions report and export the same integer dimensions, without an extra pixel.")
        model.widthText = "120"; model.heightText = "90"; model.applyDimensions()
        let typed = try ImageRendering.crop(image,normalized:model.cropRect)
        try check("crop_typed_size_at_fractional_origin",typed.width == 120 && typed.height == 90 && model.widthText == "120" && model.heightText == "90","Exact typed dimensions stay exact even with a fractional crop origin.")
        var rejected = false
        do { _ = try ImageRendering.crop(image,normalized:CGRect(x:CGFloat.nan,y:0,width:0.5,height:0.5)) } catch { rejected = true }
        try check("crop_nonfinite_coordinates_rejected",rejected,"Invalid coordinates are rejected before Core Graphics receives them.")
    }
}
