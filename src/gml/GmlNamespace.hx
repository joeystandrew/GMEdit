package gml;
import gml.GmlAPI;
import gml.GmlFuncDoc;
import tools.ArrayMap;
import tools.ArrayMapSync;
import tools.Dictionary;
import ace.extern.*;

/**
 * A namespace is a set of static and/or instance fields belonging to some context.
 * It is used for both syntax highlighting and auto-completion.
 * @author YellowAfterlife
 */
class GmlNamespace {
	public static var blank(default, null):GmlNamespace = new GmlNamespace("");
	public static inline var maxDepth = 128;
	
	public var name:String;
	public var parent:GmlNamespace = null;
	public var isObject:Bool = false;
	
	public var staticKind:Dictionary<AceTokenType> = new Dictionary();
	/** static (`Buffer.ptr`) completions */
	public var compStatic:ArrayMap<AceAutoCompleteItem> = new ArrayMap();
	public var docStaticMap:Dictionary<GmlFuncDoc> = new Dictionary();
	
	public var instKind:Dictionary<AceTokenType> = new Dictionary();
	public function getInstKind(field:String):AceTokenType {
		var q = this, n = 0;
		while (q != null && ++n <= maxDepth) {
			var t = q.instKind[field];
			if (t != null) return t;
			q = q.parent;
		}
		return null;
	}
	
	/** instance (`var b; b.ptr`) completions */
	public var compInst:ArrayMapSync<AceAutoCompleteItem> = new ArrayMapSync();
	private var compInstCache:AceAutoCompleteItems = new AceAutoCompleteItems();
	private var compInstCacheID:Int = 0;
	private var compInstCacheChain:Array<String> = [];
	public function getInstComp():AceAutoCompleteItems {
		// if this is not an object and there is no parent, the completion array is what we want:
		if (parent == null && !isObject) return compInst.array;
		
		// if completions cache is up to date, return it:
		var maxID = compInst.changeID;
		var par = parent, n = 0;
		var chainInd = 0;
		var forceUpdate = false;
		while (par != null && ++n <= maxDepth) {
			// force-update if parent chain changes:
			if (compInstCacheChain[chainInd] != par.name) {
				compInstCacheChain[chainInd] = par.name;
				forceUpdate = true;
			}
			chainInd += 1;
			//
			var parID = par.compInst.changeID;
			if (parID > maxID) maxID = parID;
			par = par.parent;
		}
		if (chainInd < compInstCacheChain.length) {
			forceUpdate = true;
			compInstCacheChain.resize(chainInd);
		}
		if (maxID == compInstCacheID && !forceUpdate) return compInstCache;
		
		// re-generate completions:
		var list = compInst.array.copy();
		compInstCacheID = maxID;
		compInstCache = list;
		
		var found = new Dictionary();
		for (c in list) found[c.name] = true;
		
		// fill out missing fields from parents:
		par = parent; n = 0;
		while (par != null && ++n < maxDepth) {
			var ql = par.compInst.array;
			var qi = ql.length;
			while (--qi >= 0) {
				var qc = ql[qi];
				if (found.exists(qc.name)) continue;
				found[qc.name] = true;
				list.unshift(qc);
			}
			par = par.parent;
		}
		// if this is an object, add built-in variables at the end of the list:
		if (isObject) for (c in GmlAPI.stdInstComp) list.push(c);
		//
		return list;
	}
	
	public var docInstMap:Dictionary<GmlFuncDoc> = new Dictionary();
	public function getInstDoc(name:String):GmlFuncDoc {
		var q = this, n = 0;
		while (q != null && ++n <= maxDepth) {
			var d = q.docInstMap[name];
			if (d != null) return d;
			q = q.parent;
		}
		return null;
	}
	
	public function new(name:String) {
		this.name = name;
	}
	
	public function addFieldHint(field:String, isInst:Bool, comp:AceAutoCompleteItem, doc:GmlFuncDoc) {
		var kind = isInst ? instKind : staticKind;
		kind[field] = doc != null ? "asset.script" : "field";
		if (doc != null) {
			var docs = isInst ? docInstMap : docStaticMap;
			docs[field] = doc;
		}
		if (comp != null && field != "") {
			var comps:ArrayMap<AceAutoCompleteItem> = isInst ? compInst : compStatic;
			comps[field] = comp;
		}
	}
	
	public function removeFieldHint(field:String, isInst:Bool) {
		var kind = isInst ? instKind : staticKind;
		kind.remove(field);
		var docs = isInst ? docInstMap : docStaticMap;
		docs.remove(field);
		
		var comps:ArrayMap<AceAutoCompleteItem> = isInst ? compInst : compStatic;
		comps.remove(field);
	}
	
	public function addStdInstComp() {
		for (item in GmlAPI.stdInstComp) {
			compInst[item.name] = item;
		}
	}
}
