package gjson


// 布尔评估模块
// 基于Go版本优化模式，将布尔逻辑评估相关的工具函数从utils.cj分离至此文件
// 职责：统一的布尔值评估、真值和假值检查逻辑

// BoolEvaluation represents the type of boolean evaluation
enum BoolEvaluation {
    EvalFalsy | EvalTruthy | EvalNull
}

// evaluateBoolean provides unified boolean evaluation logic
func evaluateBoolean(t: Result, evalType: BoolEvaluation): Bool {
    match (evalType) {
        case BoolEvaluation.EvalNull =>
            return t.kind == Kind.Null
        case BoolEvaluation.EvalFalsy =>
            match (t.kind) {
                case Kind.Null | Kind.False => return true
                case Kind.String =>
                    let b = Bool.tryParse(t.str.toAsciiLower()) ?? false
                    return !b
                case Kind.Number => return t.num == 0.0
                case _ => return false
            }
        case BoolEvaluation.EvalTruthy =>
            match (t.kind) {
                case Kind.True => return true
                case Kind.String =>
                    let b = Bool.tryParse(t.str.toAsciiLower()) ?? false
                    return b
                case Kind.Number => return t.num != 0.0
                case _ => return false
            }
    }
}

// falseish checks if a Result is logically false
func falseish(t: Result): Bool {
    return evaluateBoolean(t, BoolEvaluation.EvalFalsy)
}

// trueish checks if a Result is logically true
func trueish(t: Result): Bool {
    return evaluateBoolean(t, BoolEvaluation.EvalTruthy)
}

// nullish checks if a Result is logically null
func nullish(t: Result): Bool {
    return evaluateBoolean(t, BoolEvaluation.EvalNull)
}