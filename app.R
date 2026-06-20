# ============================================
# RSF Survival Prediction Tool (ranger)
# ============================================
library(shiny)
library(survival)
library(ranger)

# 加载数据
load("shiny_model_ranger.RData")
load("standardization_params.RData")

# 模型对象名为 rf_ranger
model <- rf_ranger
gene_list <- model$forest$independent.variable.names

gene_mean <- train_mean[gene_list]
gene_sd   <- train_sd[gene_list]
gene_sd[gene_sd == 0] <- 1e-6

# 预测函数
predict_risk <- function(input_values, input_type = "TPM") {
  if (input_type == "TPM") {
    input_values[input_values < 0] <- 0
    expr <- log2(input_values + 1)
  } else {
    expr <- input_values
  }
  expr <- expr[gene_list]
  expr_std <- (expr - gene_mean) / gene_sd
  newdata <- as.data.frame(t(expr_std))
  colnames(newdata) <- gene_list
  if (nrow(newdata) == 1) newdata <- rbind(newdata, newdata)
  pred <- predict(model, data = newdata)
  risk <- rowSums(pred$chf)
  return(risk[1])
}

# UI
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
        numericInput(paste0("gene_", i), gene_list[i], value = 0, step = 0.01)
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

# Server
server <- function(input, output, session) {
  new_data <- eventReactive(input$predict_btn, {
    vals <- vapply(seq_along(gene_list), function(i) {
      val <- input[[paste0("gene_", i)]]
      if (is.null(val) || is.na(val)) return(NA_real_)
      as.numeric(val)
    }, numeric(1))
    if (any(is.na(vals))) {
      showNotification("All genes must have valid numeric values.", type = "error")
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
        cat("Prediction failed:", e$message, "\n")
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