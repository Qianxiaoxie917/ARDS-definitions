##Function for subset selection-----------------
Select_fun <- function(dat0){
  
  dat <- dat0[dat0$ventialtion_status %in%  c("InvasiveVent", "Tracheostomy"), ]
  
  dat <- dat[!is.na(dat$Peep5) & dat$Peep5 == T, ]
  
  
  ards_columns <- names(dat)[grep("ARDS", names(dat))]
  
  for (col in ards_columns) {
    dat[[col]] <- factor(dat[[col]], levels = c("No", "Mild", "Moderate", "Severe"))
  }
  
  return(dat)
  
}

##Function for Chi-square test---------------------------
Chitest_fun <- function(dat){
  
  counts <- rbind(summary(dat$ARDS_PF), summary(dat$ARDS_SF))
  
  # Assign row and column names for clarity
  rownames(counts) <- c("PF", "SF")
  colnames(counts) <- c("No", "Mild", "Moderate", "Severe")
  
  # Perform Chi-square test
  chi_square_result <- chisq.test(counts)
  
  return(chi_square_result)
  
  
}

Chitest_fun_withoutno <- function(dat){
  
  counts <- rbind(summary(dat$ARDS_PF), summary(dat$ARDS_SF))
  
  # Assign row and column names for clarity
  rownames(counts) <- c("PF", "SF")
  colnames(counts) <- c("Mild", "Moderate", "Severe")
  
  # Perform Chi-square test
  chi_square_result <- chisq.test(counts)
  
  return(chi_square_result)
  
  
}

##Function for CMH test---------------------------------
CMHtest_fun <- function(dat1, dat2 = NULL){
  
  if(is.null(dat2)){
    
    dat2 <- dat1
    
    dat1$ARDS <- dat1$ARDS_PF
    
    dat2$ARDS <- dat2$ARDS_SF
    
  }
  
  dat1$Definition <- "Berlin"
  
  dat2$Definition <- "New"
  
  dat_combined <- rbind(dat1, dat2)
  
  test_result <- mantelhaen.test(x = dat_combined$Definition, 
                 y = dat_combined$mortality_within_30_days, z = dat_combined$ARDS)
  
  return(test_result)
}


##Function for distribution comparison plots------------------
Count_fun <- function(data, type, ARDS_col) {
  data %>%
    count(!!sym(ARDS_col)) %>%
    rename(Definition = !!sym(ARDS_col), Count = n) %>%
    mutate(Type = type)
}

DistComplot_fun <- function(dat, labs = c(expression(atop("ARDS category based on", PaO[2] / FiO[2] * " ratio")), 
                                          expression(atop("ARDS category based on", SpO[2] / FiO[2] * " ratio"))), ylb = "Number of Cases", lep = "right") {
  ARDS_cols <- names(dat)[grep("ARDS", names(dat))]
  counts <- lapply(ARDS_cols, function(col) Count_fun(dat, paste("ARDS", substr(col, 6, 7), sep = "_"), col))
  count_data <- do.call(rbind, counts)
  
  ggplot(count_data, aes(x = Type, y = Count, fill = Definition)) +
    geom_bar(stat = "identity") +
    labs(x = "", y = ylb) +
    theme_minimal() + theme(legend.position = lep) +
    scale_x_discrete(labels = labs) +
    scale_fill_manual(values = c("No" = "#feebe2", "Mild" = "#fbb4b9", "Moderate" = "#f768a1", "Severe" = "#ae017e"))
}



##Functions for mortality rates comparison-----------------------
calculate_rates <- function(dat, definition_col) {
  dat %>%
    group_by(!!sym(definition_col)) %>%
    summarise(Total = n(), Deaths = sum(mortality_within_30_days), Rate = Deaths / Total) %>%
    rename(Definition = !!sym(definition_col))
}


RatesComp_fun <- function(dat1, dat2 = NULL){
  
  rate_PF <- if (is.null(dat2)) calculate_rates(dat1, "ARDS_PF") else calculate_rates(dat1, "ARDS")
  rate_SF <- if (is.null(dat2)) calculate_rates(dat1, "ARDS_SF") else calculate_rates(dat2, "ARDS")
  
  rate_data <- rbind(data.frame(Type = "ARDS_PF", rate_PF), data.frame(Type = "ARDS_SF", rate_SF))
  
  return(rate_data)
  
  
}


##Plot for mosaic with mortality rates ---------------------------
Mosaic_fun <- function(dat, lep = "right", show_y_axis = TRUE){
  
  ARDS_levels <- levels(dat$ARDS_PF)
  
  df_agg <- dat %>%
    group_by(ARDS_PF, ARDS_SF) %>%
    summarize(
      mean_mortality = mean(`mortality_within_30_days`, na.rm = TRUE),
      mortality_count = sum(`mortality_within_30_days`, na.rm = TRUE),
      total_count = n(),
      .groups = 'drop'
    )
  
  all_combinations <- expand.grid(ARDS_SF = ARDS_levels,
                                  ARDS_PF = ARDS_levels)
  
  
  df_agg_complete <- all_combinations %>%
    left_join(df_agg, by = c("ARDS_SF", "ARDS_PF"))
  
  
  nacols <- which(is.na(df_agg_complete$total_count))
    
  df_agg_complete[nacols, 4:5] <- 0
    

  
  
  df_agg_complete$ARDS_PF <- factor(df_agg_complete$ARDS_PF, levels = c("Severe", "Moderate", "Mild" , "No"))
  df_agg_complete$ARDS_SF <- factor(df_agg_complete$ARDS_SF, levels = c("No", "Mild", "Moderate", "Severe"))
  
  
  
  p <- ggplot(df_agg_complete, aes(y = ARDS_PF, x = ARDS_SF)) +
    geom_tile(aes(fill = mean_mortality), width = 0.95, height = 0.95) +
    geom_text(
      aes(label = ifelse(total_count == 0, paste(mortality_count, "/", total_count), paste(sprintf("%.0f%%", 100 *mean_mortality), "\n(", mortality_count, "/", total_count, ")", sep = ""))),
      na.rm = TRUE
    ) +  
    scale_fill_gradient(
      low = "#feebe2",  
      high = "red",
      name = "Mortality",
      limits = c(0, 0.6),
      na.value = "white", 
      labels = scales::percent_format(accuracy = 1)
    ) +  
    labs(
      y = expression("ARDS category based on PaO"[2] / "FiO"[2] * " ratio"), 
      x = expression("ARDS category based on SpO"[2] / "FiO"[2] * " ratio"),
      title = ""
    ) +
    scale_x_discrete(position = "top") +
    theme_minimal() + theme(legend.position = lep, axis.title.y = if (show_y_axis) element_text() else element_blank(),
      axis.text.y = if (show_y_axis) element_text() else element_blank(),
      axis.ticks.y = if (show_y_axis) element_line() else element_blank())
  
  return(p)
  
}

##Plot for mortality rates comparison--------
Complot_fun <- function(rate_data, tls = "Separate subsets", lep = "right", 
                        labs = c(expression(atop("ARDS category based on", PaO[2] / FiO[2] * " ratio")), 
                                 expression(atop("ARDS category based on", SpO[2] / FiO[2] * " ratio"))), show_y_axis = TRUE) {
  
  p <- ggplot(rate_data, aes(x = Type, y = Definition, fill = Rate)) +
    geom_tile(color = "white", size = 0.5) +
    geom_text(aes(label = sprintf("%.2f", Rate)), color = "black", vjust = -0.5) +
    scale_fill_gradient(
      low = "#feebe2",  
      high = "red",
      name = "Mortality",
      limits = c(0, 0.6),
      labels = scales::percent_format(accuracy = 1)
    ) +
    labs(title = tls, x = "", y = "Severity") +
    theme_minimal() +
    theme(
      legend.position = lep, 
      plot.title = element_text(hjust = 0.5, vjust = 2), 
      axis.title.y = if (show_y_axis) element_text() else element_blank(),
      axis.text.y = if (show_y_axis) element_text() else element_blank(),
      axis.ticks.y = if (show_y_axis) element_line() else element_blank()
    ) +
    scale_x_discrete(labels = labs)
  
  return(p)
}


##Function for patients' characteristic-----------
character_func <- function(dat){

n <- nrow(dat)

cat("\nPatients selected so far:", n)

n_m <- sum(dat$mortality_within_30_days)

cat("\nMortality and percentage:", n_m, n_m/n)

n_g <- sum(dat$gender == "M")

cat("\nMale gender and percentage:", n_g, n_g/n)

n_a <- sum(grepl("BLACK", dat$race, ignore.case = TRUE))

cat("\nAfrican-American and percentage:", n_a, n_a/n)

cat("\nSummary of age:", summary(dat$age)[2:5])

cat("\nSummary of BMI:", summary(dat$bmi)[2:5])

cat("\nSummary of SOFA:", summary(dat$sofatotal)[2:5])

cat("\nSummary of number of FiO2:", summary(dat$nFiO2)[2:5])

cat("\nSummary of median of FiO2:", summary(dat$median_FiO2)[2:5])

cat("\nSummary of number of SpO2:", summary(dat$nOxy)[2:5])

cat("\nSummary of median of SpO2:", summary(dat$median_SpO2)[2:5])

cat("\nSummary of ventilation duration:", summary(dat$vent_duration)[2:5])
}










