#!/bin/bash
# Create the complete POS app folder structure and files
# Run this from your Flutter project root directory (where pubspec.yaml is)

# ==================== CORE ====================
mkdir -p lib/core/{constants,enums,errors,extensions,theme,utils}

# Core Constants
touch lib/core/constants/{app_constants.dart,firestore_collections.dart,role_permissions.dart,constants.dart}

# Core Enums
touch lib/core/enums/{user_role.dart,payment_method.dart,transaction_type.dart,sale_status.dart,discount_type.dart,enums.dart}

# Core Errors
touch lib/core/errors/{exceptions.dart,failures.dart}

# Core Extensions
touch lib/core/extensions/{string_extensions.dart,datetime_extensions.dart,num_extensions.dart}

# Core Theme
touch lib/core/theme/{app_theme.dart,app_colors.dart,app_text_styles.dart}

# Core Utils
touch lib/core/utils/{validators.dart,formatters.dart,sku_generator.dart}

# ==================== CONFIG ====================
mkdir -p lib/config/router

touch lib/config/router/{app_router.dart,route_names.dart}

# ==================== DATA ====================
mkdir -p lib/data/{datasources/{remote,local},models,repositories}

# Remote Datasources
touch lib/data/datasources/remote/{auth_remote_datasource.dart,user_remote_datasource.dart,product_remote_datasource.dart,supplier_remote_datasource.dart,sale_remote_datasource.dart,draft_remote_datasource.dart,expense_remote_datasource.dart,cost_code_remote_datasource.dart}

# Local Datasources
touch lib/data/datasources/local/local_storage_datasource.dart

# Models
touch lib/data/models/{user_model.dart,product_model.dart,supplier_model.dart,sale_model.dart,sale_item_model.dart,draft_model.dart,expense_model.dart,cost_code_model.dart,price_history_model.dart,petty_cash_model.dart}

# Repository Implementations
touch lib/data/repositories/{auth_repository_impl.dart,user_repository_impl.dart,product_repository_impl.dart,supplier_repository_impl.dart,sale_repository_impl.dart,draft_repository_impl.dart,expense_repository_impl.dart,cost_code_repository_impl.dart}

# ==================== DOMAIN ====================
mkdir -p lib/domain/{entities,repositories,usecases/{auth,user,product,pos,draft,cost_code,reports}}

# Entities
touch lib/domain/entities/{user_entity.dart,product_entity.dart,supplier_entity.dart,sale_entity.dart,sale_item_entity.dart,draft_entity.dart,expense_entity.dart,cost_code_entity.dart,petty_cash_entity.dart}

# Repository Contracts
touch lib/domain/repositories/{auth_repository.dart,user_repository.dart,product_repository.dart,supplier_repository.dart,sale_repository.dart,draft_repository.dart,expense_repository.dart,cost_code_repository.dart}

# Use Cases - Auth
touch lib/domain/usecases/auth/{sign_in_usecase.dart,sign_out_usecase.dart,verify_password_usecase.dart}

# Use Cases - User
touch lib/domain/usecases/user/{get_current_user_usecase.dart,create_user_usecase.dart,update_user_usecase.dart,delete_user_usecase.dart}

# Use Cases - Product
touch lib/domain/usecases/product/{get_products_usecase.dart,search_product_usecase.dart,create_product_usecase.dart,update_product_usecase.dart,handle_sku_variation_usecase.dart}

# Use Cases - POS
touch lib/domain/usecases/pos/{process_sale_usecase.dart,void_sale_usecase.dart,apply_discount_usecase.dart,calculate_change_usecase.dart}

# Use Cases - Draft
touch lib/domain/usecases/draft/{save_draft_usecase.dart,get_drafts_usecase.dart,update_draft_usecase.dart,delete_draft_usecase.dart}

# Use Cases - Cost Code
touch lib/domain/usecases/cost_code/{encode_cost_usecase.dart,decode_cost_usecase.dart,update_cost_mapping_usecase.dart}

# Use Cases - Reports
touch lib/domain/usecases/reports/{get_sales_report_usecase.dart,get_top_selling_usecase.dart,get_profit_report_usecase.dart}

# ==================== PRESENTATION ====================
mkdir -p lib/presentation/{providers,widgets/{common,pos,inventory},screens/{auth,dashboard,pos,drafts,inventory,receiving,suppliers,expenses,reports,users,settings,logs}}

# Providers
touch lib/presentation/providers/{auth_provider.dart,user_provider.dart,product_provider.dart,supplier_provider.dart,pos_provider.dart,cart_provider.dart,draft_provider.dart,expense_provider.dart,cost_code_provider.dart,reports_provider.dart}

# Common Widgets
touch lib/presentation/widgets/common/{app_button.dart,app_text_field.dart,loading_overlay.dart,error_dialog.dart,password_dialog.dart}

# POS Widgets
touch lib/presentation/widgets/pos/{cart_item_tile.dart,product_search_field.dart,payment_selector.dart,checkout_summary.dart}

# Inventory Widgets
touch lib/presentation/widgets/inventory/{product_list_tile.dart,cost_display_toggle.dart}

# Screens - Auth
touch lib/presentation/screens/auth/login_screen.dart

# Screens - Dashboard
touch lib/presentation/screens/dashboard/dashboard_screen.dart

# Screens - POS
touch lib/presentation/screens/pos/{pos_screen.dart,checkout_screen.dart}

# Screens - Drafts
touch lib/presentation/screens/drafts/{drafts_list_screen.dart,draft_edit_screen.dart}

# Screens - Inventory
touch lib/presentation/screens/inventory/{inventory_screen.dart,product_form_screen.dart,product_detail_screen.dart}

# Screens - Receiving
touch lib/presentation/screens/receiving/{receiving_screen.dart,bulk_receiving_screen.dart}

# Screens - Suppliers
touch lib/presentation/screens/suppliers/{suppliers_screen.dart,supplier_form_screen.dart}

# Screens - Expenses
touch lib/presentation/screens/expenses/{expenses_screen.dart,expense_form_screen.dart}

# Screens - Reports
touch lib/presentation/screens/reports/{reports_screen.dart,sales_report_screen.dart,profit_report_screen.dart}

# Screens - Users
touch lib/presentation/screens/users/{users_screen.dart,user_form_screen.dart}

# Screens - Settings
touch lib/presentation/screens/settings/{settings_screen.dart,cost_code_settings_screen.dart}

# Screens - Logs
touch lib/presentation/screens/logs/user_logs_screen.dart

# ==================== SERVICES ====================
mkdir -p lib/services

touch lib/services/{firebase_service.dart,barcode_service.dart}

# ==================== ROOT FILES ====================
touch lib/app.dart

# ==================== TEST FOLDERS ====================
mkdir -p test/core/{enums,constants,utils}
mkdir -p test/data/{models,repositories}
mkdir -p test/domain/usecases
mkdir -p test/presentation/providers

# Print success message
echo "✅ POS App folder structure created successfully!"
echo ""
echo "📁 Structure created:"
find lib -type d | sort | head -50
echo ""
echo "📄 Total files created: $(find lib -type f -name '*.dart' | wc -l)"