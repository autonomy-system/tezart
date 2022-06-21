package com.bitmark.tezart

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.liquidplayer.javascript.JSContext

class TaquitoService private constructor(context: Context) {

    companion object {
        private var INSTANCE: TaquitoService? = null

        fun getInstance(context: Context) =
            INSTANCE ?: TaquitoService(context).also { INSTANCE = it }
    }

    private val jsContext: JSContext

    private var isForging = false

    private var lastForgeResult: ((String?) -> Unit)? = null

    init {
        val jsContext = JSContext()
        jsContext.setExceptionHandler {
            if (isForging) {
                lastForgeResult?.invoke(null)
                isForging = false
            }
        }

        val ins = context.resources.openRawResource(R.raw.taquito_local_forging)
        val content = ins.bufferedReader().use { it.readText() }
        jsContext.evaluateScript(content)
        jsContext.evaluateScript("var forger = new taquito_local_forging.LocalForger();")
        this.jsContext = jsContext
    }

    fun forge(operationPayload: String, result: (String?) -> Unit) {
        if (isForging) {
            result.invoke(null)
            return
        }

        lastForgeResult = result
        isForging = true

        jsContext.evaluateScript(
            """
            var forgeResult = null;
            forger.forge($operationPayload).then(
                function(value) { forgeResult = value; },
                function(error) { forgeResult = ""; }
            );
            """
        )

        val handler = Handler(Looper.getMainLooper())
        fun checkAndReturnValue(attempt: Int) {
            handler.postDelayed({
                val forgeResult = jsContext.property("forgeResult")
                if (!forgeResult.isNull) {
                    isForging = false
                    lastForgeResult = null
                    result(forgeResult.toString())
                    jsContext.property("forgeResult", null)
                } else {
                    if (attempt < 5) {
                        checkAndReturnValue(attempt + 1)
                    } else {
                        isForging = false
                        lastForgeResult = null
                        result(null)
                    }
                }
            }, 100L * attempt)
        }

        checkAndReturnValue(0)
    }
}