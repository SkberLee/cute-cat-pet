// Re-save the already-open document through LibreSprite's official encoder.
var s = app.activeSprite;
if (!s) {
  console.log("finalize: no active sprite");
} else {
  try { s.commit(); } catch (e) { console.log("commit: " + e); }
  try { s.save(); console.log("saved " + s.filename); } catch (e) { console.log("save: " + e); }
}
