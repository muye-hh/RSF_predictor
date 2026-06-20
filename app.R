# ============================================
# RSF Survival Prediction Tool (ranger)
# 自动标准化：支持 TPM 或 log2(TPM+1) 输入
# ============================================
library(shiny)
library(survival)
library(ranger)

# ---------- 加载模型与标准化参数 ----------
load("shiny_model_ranger.RData")        # best_model, gene_list, median_cut
load("standardization_params.RData")    # train_mean, train_sd

# 提取模型基因对应的均值和标准差
gene_mean <- train_mean[gene_list]
gene_sd   <- train_sd[gene_list]
# 防止标准差为0（理论上不会）
gene_sd[gene_sd == 0] <- 1e-6

# ---------- 风险预测函数（含自动标准化） ----------
predict_risk <- function(input_values, input_type = "TPM") {
  # input_values: 命名数值向量，长度为16，名称为基因名
  # input_type: "TPM" 或 "log2(TPM+1)"
  
  # 步骤1: 若为 TPM，转换为 log2(TPM+1)
  if (input_type == "TPM") {
    input_values[input_values < 0] <- 0
    expr <- log2(input_values + 1)
  } else {
    expr <- input_values
  }
  
  # 步骤2: z-score 标准化（使用训练集的均值和标准差）
  expr <- expr[gene_list]
  expr_std <- (expr - gene_mean) / gene_sd
  
  # 步骤3: 构建数据框并预测
  newdata <- as.data.frame(t(expr_std))
  colnames(newdata) <- gene_list
  
  # ranger 对单行预测的保护
  if (nrow(newdata) == 1) {
    newdata <- rbind(newdata, newdata)
  }
  
  pred <- predict(best_model, data = newdata)
  risk <- rowSums(pred$chf)
  return(risk[1])
}

# ---------- UI ----------
ui <- fluidPage(
  titlePanel("RSF Survival Prediction Tool"),
  sidebarLayout(
    sidebarPanel(
      h4("Input Type"),
      radioButtons("input_type", "Expression data type:",
                   choices = c("TPM", "log2(TPM+1)"),
                   selected = "TPM", inline = TRUE),
      hr(),
      h4("Enter Gene Expression Values"),
      lapply(seq_along(gene_list), function(i) {
        numericInput(
          inputId = paste0("gene_", i),
          label   = gene_list[i],
          value   = 0,         # 可自行调整默认值
          step    = 0.01
        )
      }),
      actionButton("predict_btn", "Calculate Risk", class = "btn-primary"),
      width = 3
    ),
    mainPanel(
      h3("Prediction Result"),
      verbatimTextOutput("risk_output")
    )
  )
)

# ---------- Server ----------
server <- function(input, output, session) {
  
  new_data <- eventReactive(input$predict_btn, {
    # 提取所有基因的输入值
    vals <- vapply(seq_along(gene_list), function(i) {
      val <- input[[paste0("gene_", i)]]
      if (is.null(val) || is.na(val)) return(NA_real_)
      as.numeric(val)
    }, numeric(1))
    
    if (any(is.na(vals))) {
      showNotification("所有基因必须填入有效数值！", type = "error")
      return(NULL)
    }
    
    names(vals) <- gene_list
    list(values = vals, type = input$input_type)
  })
  
  output$risk_output <- renderPrint({
    req(new_data())
    risk <- tryCatch(
      predict_risk(new_data()$values, new_data()$type),
      error = function(e) {
        cat("预测失败:", e$message, "\n")
        return(NULL)
      }
    )
    if (!is.null(risk)) {
      group <- ifelse(risk >= median_cut, "High Risk", "Low Risk")
      cat("Risk Score:", round(risk, 4), "\n")
      cat("Risk Group:", group, "\n")
      cat("(Median cutoff =", round(median_cut, 4), ")\n")
    }
  })
}

shinyApp(ui, server)
